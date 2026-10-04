"""Validate MATLAB clean histories and add them to the six-section report."""
from pathlib import Path
import csv,json,shutil
import numpy as np
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
R=Path(__file__).resolve().parents[1];Q=R/'runs/pilot/clean_convergence_20261004';D=R/'reports/research_summary_20261004'
status=json.loads((Q/'status.json').read_text());assert status['state']=='completed'
rows=list(csv.DictReader((Q/'curves.csv').open()));assert len(rows)==808
# MATLAB readtable normalized reserved word 'case' to xCase; retain raw files.
for r in rows:
 if 'xCase' in r:r['case']=r.pop('xCase')
raw=[]
for layout in ['periodic','aperiodic']:
 for method in ['HIO','ER','RAAR','LBFGS']:
  raw.extend(csv.DictReader((Q/f'{layout}_clean_{method}.csv').open()))
assert len(raw)==len(rows)
for a,b in zip(raw,rows):
 assert a.keys()==b.keys()
 for key in a:
  if key in ['case','method']:assert a[key]==b[key]
  else:assert abs(float(a[key])-float(b[key]))<1e-12
import hashlib
prov=json.loads((Q/'provenance.json').read_text())
for q in prov['sources']:
 assert hashlib.sha256((R/q['path'].replace('\\','/')).read_bytes()).hexdigest()==q['sha256']

checks=[]
for f in Q.glob('*_check.json'):
 checks.extend(json.loads(f.read_text()))
assert len(checks)==16 and all(q['relative_field_delta']<1e-11 for q in checks)
with (D/'data/clean_curves.csv').open('w',newline='') as f:
 w=csv.DictWriter(f,fieldnames=rows[0]);w.writeheader();w.writerows(rows)
plt.rcParams.update({'font.size':11,'pdf.fonttype':42,'svg.fonttype':'none'})
fig,axs=plt.subplots(2,2,figsize=(11,7),layout='constrained');best=[]
for j,l in enumerate(['periodic','aperiodic']):
 for m,col in zip(['HIO','ER','RAAR','LBFGS'],['#0072B2','#D55E00','#009E73','#CC79A7']):
  rr=[r for r in rows if r['case']==l+'_clean' and r['method']==m];assert len(rr)==101
  r=min(rr,key=lambda r:(float(r['field_nrmse']),int(r['iterations']),int(r['propagations'])))
  best.append({'layout':l,'method':m,'best_iteration':int(r['iterations']),'min_field_nrmse':float(r['field_nrmse']),'propagations':int(r['propagations'])})
  states={int(r['iterations']):r for r in rr};x=sorted(states)
  for k,metric in enumerate(['field_nrmse','phase_rmse_rad']):
   axs[k,j].plot(x,[float(states[i][metric]) for i in x],color=col,label=m)
  axs[0,j].scatter(int(r['iterations']),float(r['field_nrmse']),marker='*',s=75,color=col,edgecolor='black',lw=.3,zorder=4)
 for k,label in enumerate(['Complex-field NRMSE','Phase RMSE (rad)']):
  axs[k,j].set(title=l.capitalize()+' / noiseless',xlabel='Accepted solver iteration',ylabel=label);axs[k,j].grid(alpha=.2);axs[k,j].legend(ncol=2)
for ext in ['pdf','png','svg']:fig.savefig(D/'figures'/f'clean_iterations.{ext}',dpi=300)
plt.close(fig)
with (D/'data/clean_best.csv').open('w',newline='') as f:w=csv.DictWriter(f,fieldnames=best[0]);w.writeheader();w.writerows(best)
insert=r'''\begin{landscape}\thispagestyle{empty}
\section{无噪声情况对比}
\textbf{完整iteration曲线。} 两类布局、四方法，复场与相位误差分别展示；星号标出各方法本次已保存轨迹中的最低复场误差。与原80／200次传播的16项复场检查全部一致。
\begin{center}\includegraphics[width=242mm,height=120mm,keepaspectratio]{figures/clean_iterations.pdf}\end{center}
{\small 曲线由MATLAB补录，每2次传播评分一次；横轴使用实际接受iteration。最低点为回顾性真值评价。逐步数据与最佳iteration见\path{data/clean_curves.csv}、\path{data/clean_best.csv}。}
\end{landscape}\clearpage
\subsection*{无噪声对比（续）：共同检查点与重建图像}'''
for p in [R/'tools/research_summary_template.tex',D/'main.tex']:
 s=p.read_text();key=r'\section{无噪声情况对比}'
 if 'figures/clean_iterations.pdf' not in s:s=s.replace(key,insert)
 s=s.replace('无噪声沿用原保存的共同80次传播检查点，展示两类布局的振幅和校正相位。后续200次检查点仅作补充；现有无噪声数据只有稀疏检查点，不能据此确定全轨迹最低误差。','以下复用原共同80次传播检查点，展示两类布局的振幅和校正相位；200次结果仅作补充。完整迭代轨迹与各自最佳点见上页。')
 p.write_text(s)
(D/'data/clean_history_audit.json').write_text(json.dumps({'rows':len(rows),'old_checkpoint_matches':len(checks),'best':best},indent=2))
print(json.dumps(best,indent=2))
