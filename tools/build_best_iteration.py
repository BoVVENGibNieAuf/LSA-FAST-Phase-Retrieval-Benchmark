"""Individual-run oracle iteration analysis, from saved scalar curves only."""
from pathlib import Path
import csv,json
import numpy as np
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
R=Path(__file__).resolve().parents[1];D=R/'reports/research_summary_20261004';A=D/'data';F=D/'figures'
rows=list(csv.DictReader((A/'curves.csv').open()));methods=['HIO','ER','RAAR','LBFGS'];seeds=[41001,41002,41003];best=[];table_rows=[]
fig,axes=plt.subplots(2,2,figsize=(11,7),layout='constrained')
for ax,(layout,p) in zip(axes.flat,[(l,p) for l in ['periodic','aperiodic'] for p in [1,10]]):
 for m,col in zip(methods,['#0072B2','#D55E00','#009E73','#CC79A7']):
  trio=[]
  for j,seed in enumerate(seeds):
   rr=[r for r in rows if r['layout']==layout and int(r['p_blank'])==p and r['method']==m and int(r['seed'])==seed]
   r=min(rr,key=lambda r:(float(r['field_nrmse']),int(r['iterations']),int(r['propagations'])))
   q={'layout':layout,'p_blank':p,'method':m,'seed':seed,'best_iteration':int(r['iterations']),'min_field_nrmse':float(r['field_nrmse']),'propagations_at_best':int(r['propagations']),'phase_rmse_at_best':float(r['phase_rmse_rad'])};best.append(q);trio.append(q)
   # Rejected line trials repeat accepted states; retain one point per iteration.
   states={int(x['iterations']):float(x['field_nrmse']) for x in rr};x=sorted(states)
   ax.plot(x,[states[k] for k in x],color=col,alpha=.65,lw=1.1,label=m if j==0 else None)
   ax.scatter(q['best_iteration'],q['min_field_nrmse'],color=col,marker='*',s=60,zorder=4,edgecolor='black',linewidth=.3)
  pairs=[f"{q['best_iteration']} / {q['min_field_nrmse']:.4f}" for q in trio]
  table_rows.append(f"{'周期' if layout=='periodic' else '非周期'} & {p} & {m} & "+' & '.join(pairs)+r'\\')
 ax.set(title=f'{layout.capitalize()} / blank p={p}',xlabel='Accepted solver iteration',ylabel='Complex-field NRMSE');ax.grid(alpha=.2);ax.legend(ncol=2)
for ext in ['pdf','png','svg']:fig.savefig(F/f'noise_iterations.{ext}',dpi=300)
plt.close(fig)
with (A/'per_run_best.csv').open('w',newline='') as f:
 w=csv.DictWriter(f,fieldnames=best[0]);w.writeheader();w.writerows(best)
(A/'selection_rule.json').write_text(json.dumps({'rule':'Independently minimize field NRMSE of each method and seed over its entire saved trajectory. Report the actual accepted iteration and value at that minimum. Ties: first iteration, then first propagation. No averaging before selection.','scope':'Retrospective truth-based best within the recorded run, not an automatic stopping rule or a proof of global optimality.','legacy':'early_minima.csv preserves the previous mean-curve selection; superseded for the main report by per_run_best.csv.'},indent=2))
assert len(best)==48
print('48 individual trajectories analyzed; values rounded only for display')
