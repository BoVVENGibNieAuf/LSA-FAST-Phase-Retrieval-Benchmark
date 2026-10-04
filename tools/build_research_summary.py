"""Recompose six-section report from accepted MATLAB artifacts; no solver reruns."""
from pathlib import Path
import csv,json,shutil
import numpy as np
from scipy.io import loadmat
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
R=Path(__file__).resolve().parents[1];D=R/'reports/research_summary_20261004';F=D/'figures';A=D/'data'
for p in [D,F,A]:p.mkdir(exist_ok=True,parents=True)
P=R/'reports/poisson_stage_20261004';M=['HIO','ER','RAAR','LBFGS'];C=['#0072B2','#D55E00','#009E73','#CC79A7'];Ls=['periodic','aperiodic']
rows=list(csv.DictReader((P/'data/curves.csv').open()));old=list(csv.DictReader((R/'reports/latex_delivery_20261004/data/metrics.csv').open()))
for f in ['curves.csv','final_metrics.csv','audit.json']:shutil.copy2(P/'data'/f,A/f)
shutil.copy2(R/'reports/latex_delivery_20261004/data/metrics.csv',A/'clean_and_historical_metrics.csv')
plt.rcParams.update({'font.size':11,'pdf.fonttype':42,'svg.fonttype':'none'})
selected=[]
fig,axs=plt.subplots(2,2,figsize=(11,7),layout='constrained',sharex=True)
for ax,(layout,p) in zip(axs.flat,[(l,p) for l in Ls for p in [1,10]]):
 for m,c in zip(M,C):
  groups=[[x for x in rows if x['layout']==layout and int(x['p_blank'])==p and x['method']==m and int(x['seed'])==s] for s in [41001,41002,41003]]
  v=np.array([[float(x['field_nrmse']) for x in g] for g in groups]);mean=v.mean(0);i=int(mean.argmin());b=int(groups[0][i]['budget']);assert b<=6
  q={'layout':layout,'p_blank':p,'method':m,'budget':b,'iteration_min':min(int(g[i]['iterations']) for g in groups),'iteration_max':max(int(g[i]['iterations']) for g in groups),'field_mean':mean[i],'field_sd':v[:,i].std(ddof=1),'phase_at_field_min_mean':np.mean([float(g[i]['phase_rmse_rad']) for g in groups]),'phase_at_field_min_sd':np.std([float(g[i]['phase_rmse_rad']) for g in groups],ddof=1)};selected.append(q)
  x=np.arange(0,201,2);mask=x<=20
  ax.plot(x[mask],mean[mask],color=c,label=m,marker='o',ms=3);ax.fill_between(x[mask],v[:,mask].min(0),v[:,mask].max(0),color=c,alpha=.12)
  ax.scatter(b,mean[i],marker='*',s=90,color=c,edgecolor='black',lw=.35,zorder=5)
 ax.set(title=f'{layout.capitalize()} / blank p={p}',xlabel='Forward / adjoint propagation calls',ylabel='Complex-field NRMSE',xticks=np.arange(0,21,2));ax.grid(alpha=.2);ax.legend(ncol=2)
for ext in ['pdf','svg','png']:fig.savefig(F/f'noise_early.{ext}',dpi=300)
plt.close(fig)
with (A/'early_minima.csv').open('w',newline='') as f:w=csv.DictWriter(f,fieldnames=selected[0]);w.writeheader();w.writerows(selected)
(A/'selection_rule.json').write_text(json.dumps({'rule':'Minimize the three-seed mean field NRMSE over all saved budgets 0:2:200 separately for each layout/p/method, then report all seeds at that same selected budget; not mean of per-seed minima.','selection':'Retrospective truth-guided diagnostic, not deployable stopping criterion.','all_selected_budgets':sorted(set(int(x['budget']) for x in selected))},indent=2))
shutil.copy2(P/'figures/convergence.pdf',F/'noise_full_history.pdf')
shutil.copy2(R/'reports/latex_delivery_20261004/figures/geometry.png',F/'geometry.png')
for name in ['08_author_display39.png','09_final_iteration40_display.png','10_calibration_convergence.png']:
 shutil.copy2(R/'runs/pilot/author_20260927_225947'/name,F/name)
shutil.copy2(R/'runs/pilot/author_20260927_225947/metrics.json',A/'author_metrics.json')
# Saved clean fields at the earlier available common checkpoint, 80 calls.
for li,layout in enumerate(Ls):
 source=f'mcf_20261003_224006_279_0{li+1}'
 truth=loadmat(R/'evaluation_only'/source/'mixed_truth.mat',simplify_cells=True);d=loadmat(R/'runs/pilot'/source/'mixed_clean_input.mat',simplify_cells=True)
 ref=truth['truth'];roi=truth['roi'].astype(bool);fields=[ref]
 for m in M:
  z=loadmat(R/'runs/pilot/four_20261003_224047_034'/f'{layout}_clean'/f'{m}_result.mat',simplify_cells=True)['result']['snapshots'];fields.append(next(x for x in z if int(x['budget'])==80)['physical_output'])
 fig,axs=plt.subplots(2,5,figsize=(12,5.5),layout='constrained')
 vmax=max(float(np.abs(u).max()) for u in fields)
 for j,(label,u) in enumerate(zip(['Truth']+M,fields)):
  theta=np.angle(np.sum(np.conj(ref[roi])*u[roi]));phase=np.where(roi,np.angle(u*np.conj(d['calibration'])*np.exp(-1j*theta)),np.nan)
  for k,v in enumerate([np.abs(u),phase]):
   im=axs[k,j].imshow(v,origin='upper',extent=[-64,64,-64,64],cmap='viridis' if k==0 else 'twilight',vmin=0 if k==0 else -np.pi,vmax=vmax if k==0 else np.pi)
   axs[k,j].set(xlim=(-32,32),ylim=(-32,32),title=label if k==0 else '',xlabel='x (um)');axs[k,j].set_ylabel(('Amplitude' if k==0 else 'Phase')+' / y (um)' if j==0 else '')
   if j==4:fig.colorbar(im,ax=axs[k,:],shrink=.7,label='Relative amplitude' if k==0 else 'rad')
 for ext in ['pdf','png']:fig.savefig(F/f'{layout}_clean80.{ext}',dpi=300)
 plt.close(fig)
clean=[]
for l in Ls:
 for m in M:
  a=next(x for x in old if x['case']==l+'_clean' and x['method']==m and int(x['budget'])==80);b=next(x for x in old if x['case']==l+'_clean' and x['method']==m and int(x['budget'])==200)
  clean.append({'layout':l,'method':m,'field80':a['field_nrmse'],'phase80':a['phase_rmse_rad'],'field200':b['field_nrmse']})
with (A/'clean_comparison.csv').open('w',newline='') as f:w=csv.DictWriter(f,fieldnames=clean[0]);w.writeheader();w.writerows(clean)
print('Retrospective minima:',[(q['layout'],q['p_blank'],q['method'],q['budget'],round(q['field_mean'],4)) for q in selected])
clean_tex=[]
for q in csv.DictReader((A/'clean_best.csv').open()):
 clean_tex.append(f"{'周期' if q['layout']=='periodic' else '非周期'} & {q['method']} & {q['best_iteration']} & {float(q['min_field_nrmse']):.4f}\\\\")
import runpy
noise_tex=runpy.run_path(str(R/'tools/build_best_iteration.py'))['table_rows']
tex=(R/'tools/research_summary_template.tex').read_text().replace('CLEAN_TABLE','\n'.join(clean_tex)).replace('NOISE_TABLE','\n'.join(noise_tex));(D/'main.tex').write_text(tex)
for f in ['build.sh','build.cmd']:shutil.copy2(R/'reports/latex_delivery_20261004'/f,D/f)
(D/'README.md').write_text('# 六节研究进展报告\n\n顺序：简报、原文章复现结果、测试数据生成和噪声模型、无噪声对比、有噪声对比、小结。\n\nmain.tex 用XeLaTeX编译两次，或运行tectonic。figures与data为本报告使用的实际结果。\n\n最佳iteration与最低误差按每种方法、每次运行分别回顾性选点；不是已验证自动停止规则。原始完整曲线及选点定义见data，完整含噪曲线见figures/noise_full_history.pdf。\n\n源码、原始数据、历史MAT恢复与7篇引用见报告第6节。主项目运行和绘图入口见仓库README。\n')
