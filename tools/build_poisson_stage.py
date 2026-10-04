"""Validate real MATLAB receipts/fields and publish two plots + one table.
No reconstruction backend here. Run only after MATLAB reports 48/48.
"""
from pathlib import Path
import csv, json, hashlib, shutil
import numpy as np
from scipy.io import loadmat
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
ROOT=Path(__file__).resolve().parents[1]
RUN=ROOT/'runs/pilot/poisson_stage_20261004'
OUT=ROOT/'reports/poisson_stage_20261004'
METHODS=['HIO','ER','RAAR','LBFGS']
LAYOUTS=['periodic','aperiodic']
COLORS=['#0072B2','#D55E00','#009E73','#CC79A7']
def sha(p): return hashlib.sha256(p.read_bytes()).hexdigest()
def main():
 status=json.loads((RUN/'status.json').read_text())
 assert status['state']=='completed' and status['completed']==48, 'Real MATLAB 48/48 completion required'
 OUT.mkdir(exist_ok=True); (OUT/'figures').mkdir(exist_ok=True); (OUT/'data').mkdir(exist_ok=True)
 cfg=json.loads((RUN/'config.json').read_text()); curves=[]; finals=[]; checks=0; audits=[]
 for li,layout in enumerate(LAYOUTS):
  truth=loadmat(ROOT/'evaluation_only'/cfg['source_runs'][li]/'mixed_truth.mat')
  ref=truth['truth']; roi=truth['roi'].astype(bool)
  for p in [1,10]:
   for seed in [41001,41002,41003]:
    d=RUN/f'{layout}_p{p}_seed{seed}'; inp=loadmat(d/'input.mat',simplify_cells=True)
    counts=inp['amplitude']**2*inp['camera']['exposure']
    assert np.max(np.abs(counts-np.rint(counts)))<1e-8
    assert inp['camera']['read_sigma_electrons']==0 and inp['camera']['p_blank']==p
    audits.append({'case':d.name,'input_sha256':sha(d/'input.mat'),'sample_expected_mean':inp['camera']['expected_sample_mean'],'sample_actual_mean':counts.mean()})
    for m in METHODS:
     receipt=json.loads((d/f'{m}_done.json').read_text())
     for key,file in [('input_sha256','input.mat'),('result_sha256',f'{m}_result.mat'),('curve_sha256',f'{m}_curve.csv')]:
      assert sha(d/file)==receipt[key]
     rows=list(csv.DictReader((d/f'{m}_curve.csv').open()))
     assert len(rows)==101 and [int(x['budget']) for x in rows]==list(range(0,201,2))
     for row in rows:
      for key in ['p_blank','seed','budget','iterations','propagations','state_propagations']:row[key]=int(row[key])
      for key in ['field_nrmse','phase_rmse_rad']:row[key]=float(row[key]);assert np.isfinite(row[key])
      assert row['method']==m and row['layout']==layout and row['p_blank']==p and row['seed']==seed
     assert all(a['propagations']<=b['propagations']<=200 and a['iterations']<=b['iterations'] for a,b in zip(rows,rows[1:]))
     result=loadmat(d/f'{m}_result.mat',simplify_cells=True)['result'];u=result['snapshots']['physical_output']
     theta=np.angle(np.sum(np.conj(ref[roi])*u[roi])); aligned=u*np.exp(-1j*theta)
     nrmse=np.linalg.norm(aligned-ref)/np.linalg.norm(ref)
     phase=np.sqrt(np.mean(np.angle(aligned[roi]*np.conj(ref[roi]))**2))
     assert abs(nrmse-rows[-1]['field_nrmse'])<1e-10
     assert abs(phase-rows[-1]['phase_rmse_rad'])<1e-10
     checks+=2;curves.extend(rows);finals.append(rows[-1])
 for name,data in [('curves',curves),('final_metrics',finals)]:
  with (OUT/'data'/f'{name}.csv').open('w') as f:
   w=csv.DictWriter(f,fieldnames=data[0]);w.writeheader();w.writerows(data)
 summary=[]
 for layout in LAYOUTS:
  for p in [1,10]:
   for m in METHODS:
    group=[r for r in finals if r['layout']==layout and r['p_blank']==p and r['method']==m]
    row={'layout':layout,'p_blank':p,'method':m}
    for metric in ['field_nrmse','phase_rmse_rad']:
     v=[r[metric] for r in group];row[metric+'_mean']=float(np.mean(v));row[metric+'_sd']=float(np.std(v,ddof=1))
    summary.append(row)
 with (OUT/'data/summary.csv').open('w') as f:
  w=csv.DictWriter(f,fieldnames=summary[0]);w.writeheader();w.writerows(summary)
 plt.rcParams.update({'font.size':11,'pdf.fonttype':42,'svg.fonttype':'none'})
 fig,axs=plt.subplots(2,2,figsize=(11,7),layout='constrained',sharex=True)
 for ax,(layout,p) in zip(axs.flat,[(l,p) for l in LAYOUTS for p in [1,10]]):
  for m,c in zip(METHODS,COLORS):
   vals=np.array([[r['field_nrmse'] for r in curves if r['layout']==layout and r['p_blank']==p and r['method']==m and r['seed']==s] for s in [41001,41002,41003]])
   x=np.arange(0,201,2);ax.plot(x,vals.mean(0),color=c,label=m);ax.fill_between(x,vals.min(0),vals.max(0),color=c,alpha=.12)
  ax.set(title=f'{layout.capitalize()} / blank p={p}',xlabel='Propagation budget (forward + adjoint calls)',ylabel='Complex-field NRMSE');ax.grid(alpha=.2);ax.legend(ncol=2)
 for ext in ['pdf','svg','png']:fig.savefig(OUT/'figures'/f'convergence.{ext}',dpi=300)
 plt.close(fig)
 old=list(csv.DictReader((ROOT/'reports/latex_delivery_20261004/data/metrics.csv').open()))
 fig,axs=plt.subplots(1,2,figsize=(11,4.4),layout='constrained',sharey=True)
 for ax,layout in zip(axs,LAYOUTS):
  for mi,(m,c) in enumerate(zip(METHODS,COLORS)):
   offset=(mi-1.5)*.12;means=[]
   for xi,p in enumerate([1,10]):
    values=[r['field_nrmse'] for r in finals if r['layout']==layout and r['p_blank']==p and r['method']==m]
    ax.scatter(xi+offset+np.array([-.025,0,.025]),values,color=c,s=20,alpha=.7);means.append(np.mean(values))
   clean=next(float(r['field_nrmse']) for r in old if r['case']==layout+'_clean' and r['method']==m and int(r['budget'])==200)
   ax.plot(np.array([0,1])+offset,means,'_',color=c,ms=14,mew=2,label=m);ax.scatter(2+offset,clean,color=c,marker='D',s=26)
  ax.set(title=layout.capitalize(),xticks=[0,1,2],xticklabels=['p = 1','p = 10','Noiseless\n(saved baseline)'],ylabel='Final complex-field NRMSE');ax.grid(axis='y',alpha=.2);ax.legend(ncol=2)
 for ext in ['pdf','svg','png']:fig.savefig(OUT/'figures'/f'noise_levels.{ext}',dpi=300)
 plt.close(fig)
 audit={'completed_solves':48,'curve_rows':len(curves),'independent_final_metric_checks':checks,'inputs':audits,'backend':status['backend']}
 (OUT/'data/audit.json').write_text(json.dumps(audit,indent=2))
 lines=['# Poisson 噪声阶段结果','',f'48/48 MATLAB 求解完成；{checks} 项最终误差独立复核通过。','', '|布局|空白计数 p|方法|复场 NRMSE（均值 ± SD）|相位 RMSE/rad（均值 ± SD）|','|---|---:|---|---:|---:|']
 for r in summary:lines.append(f"|{r['layout']}|{r['p_blank']}|{r['method']}|{r['field_nrmse_mean']:.4f} ± {r['field_nrmse_sd']:.4f}|{r['phase_rmse_rad_mean']:.4f} ± {r['phase_rmse_rad_sd']:.4f}|")
 lines+=['','![逐步误差](figures/convergence.png)','','均值曲线与三个种子的最小–最大范围；横轴为预算，早停时延续最后状态，实际调用数见CSV。','','![最终误差](figures/noise_levels.png)','','散点为三次重复，横线为均值；无噪声菱形是原始保存结果。不同预算下真值仅用于评价，未用于早停或选参。','','空白参考 p=1/10 平均检测计数/像素/帧，全256×256帧平均。保持已知理想校准；不代表低光子条件下端到端校准性能。三次重复不作显著性结论。']
 (OUT/'REPORT.md').write_text('\n'.join(lines))
 shutil.copy2(ROOT/'reports/POISSON_STAGE_PROTOCOL_20261004.md',OUT/'PROTOCOL.md')
 print(json.dumps(audit,indent=2))
if __name__=='__main__':main()
