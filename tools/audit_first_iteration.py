"""Audit existing scalar scores and recorded objectives; no reconstruction."""
from pathlib import Path
import csv,json
import numpy as np
from scipy.io import loadmat
R=Path(__file__).resolve().parents[1];run=R/'runs/pilot/poisson_stage_20261004';out=R/'reports/research_summary_20261004/data'
curves=list(csv.DictReader((out/'curves.csv').open()));rows=[]
for layout in ['periodic','aperiodic']:
 for p in [1,10]:
  for seed in [41001,41002,41003]:
   case=f'{layout}_p{p}_seed{seed}';z=loadmat(run/case/'LBFGS_result.mat',simplify_cells=True)['result'];tr=z['objective_trace'];acc=[x for x in tr if x['accepted']]
   rr=[x for x in curves if x['layout']==layout and int(x['p_blank'])==p and int(x['seed'])==seed and x['method']=='LBFGS']
   a=next(x for x in rr if int(x['iterations'])==1);initial=rr[0];final=rr[-1]
   assert all(y['objective']<=x['objective']+1e-9 for x,y in zip(acc,acc[1:]))
   firstobj=next(x['objective'] for x in acc if x['calls']==int(a['propagations']))
   rows.append({'case':case,'first_update_calls':int(a['propagations']),'initial_phase_rmse':float(initial['phase_rmse_rad']),'first_phase_rmse':float(a['phase_rmse_rad']),'first_field_nrmse':float(a['field_nrmse']),'final_field_nrmse':float(final['field_nrmse']),'first_objective':firstobj,'final_objective':acc[-1]['objective'],'accepted_objectives_monotone':True})
with (out/'first_iteration_audit.csv').open('w',newline='') as f:w=csv.DictWriter(f,fieldnames=rows[0]);w.writeheader();w.writerows(rows)
for p in [1,10]:
 rr=[r for r in rows if f'_p{p}_' in r['case']]
 print('p',p,'first phase initial→first',[(l,round(np.mean([r['initial_phase_rmse'] for r in rr if r['case'].startswith(l+'_')]),4),round(np.mean([r['first_phase_rmse'] for r in rr if r['case'].startswith(l+'_')]),4)) for l in ['periodic','aperiodic']])
print('LBFGS: objective lower but truth error higher than first update:',sum(r['final_objective']<r['first_objective'] and r['final_field_nrmse']>r['first_field_nrmse'] for r in rows),'/',len(rows))
