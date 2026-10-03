"""Plot MATLAB diagnostics with native iteration and fair propagation axes."""
from pathlib import Path
import csv,json,hashlib
import numpy as np
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
ROOT=Path(__file__).resolve().parents[1]
D=ROOT/'reports/latex_delivery_20261004'
rows=list(csv.DictReader((D/'data/convergence.csv').open()))
old=list(csv.DictReader((D/'data/metrics.csv').open()))
methods=['HIO','ER','RAAR','LBFGS']; cases=['periodic_clean','aperiodic_clean','periodic_shot_read','aperiodic_shot_read']
colors=['#0072B2','#D55E00','#009E73','#CC79A7'];styles=['-','--','-.',':']
plt.rcParams.update({'font.family':'DejaVu Sans','font.size':12,'axes.titlesize':14,'axes.labelsize':12,'legend.fontsize':11,'pdf.fonttype':42,'svg.fonttype':'none'})
checks=0
for r in old:
 if r['method']=='ZERO':continue
 v=next(x for x in rows if x['case']==r['case'] and x['method']==r['method'] and int(x['propagations'])==int(r['budget']))
 for key in ['field_nrmse','phase_rmse_rad']:
  assert abs(float(v[key])-float(r[key]))<1e-10,(v,r)
  checks+=1
for metric in ['field_nrmse','phase_rmse_rad']:
 for axis in ['iterations','propagations']:
  fig,axs=plt.subplots(2,2,figsize=(10.4,6.7),layout='constrained',sharex=True,sharey='row')
  for ci,(ax,case) in enumerate(zip(axs.flat,cases)):
   for method,col,sty in zip(methods,colors,styles):
    rr=[r for r in rows if r['case']==case and r['method']==method]
    if axis=='iterations':
     # Rejected L-BFGS trials retain the same accepted state; do not invent steps.
     rr=list({int(r[axis]):r for r in rr}.values())
    ax.plot([int(r[axis]) for r in rr],[float(r[metric]) for r in rr],color=col,ls=sty,lw=1.5,marker='o',markersize=5,label='L-BFGS' if method=='LBFGS' else method)
   title=('Aperiodic' if case.startswith('aperiodic') else 'Periodic')+' / '+('noiseless' if case.endswith('clean') else 'shot + read noise')
   ax.set_title(f'({chr(97+ci)}) {title}')
   ax.set_xlabel('Accepted solver iterations' if axis=='iterations' else 'Forward / adjoint propagation calls')
   ax.set_ylabel('Complex-field NRMSE' if metric=='field_nrmse' else 'Phase RMSE (rad)')
   ax.set_xlim(0,100 if axis=='iterations' else 200);ax.grid(alpha=.22);ax.legend(loc='best',ncol=2)
  for ext in ['pdf','svg','png']:
   fig.savefig(D/'figures'/f'convergence_{metric}_{axis}.{ext}',dpi=600 if ext=='png' else 150)
  plt.close(fig)
(D/'data/convergence_plot_audit.json').write_text(json.dumps({'rows':len(rows),'original_metric_checks':checks,'source':'Original MATLAB saved checkpoints: initialization, 80 and 200 propagation calls; connecting lines are visual guides, not dense histories','smoothing':False},indent=2))
print('PASS',len(rows),'rows;',checks,'original metric checks')
