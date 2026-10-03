"""Replot saved fields (no solver rerun), audit noise, build large-panel delivery."""
from pathlib import Path
import json, hashlib, zipfile
import numpy as np
from scipy.io import loadmat
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
import fitz
import build_mentor_delivery as b

b.STEM='FAST_圆形MCF_出版级图版_20261004'
figdir=b.OUT/'publication_figures_20261004';figdir.mkdir(exist_ok=True)
plt.rcParams.update({'font.family':'DejaVu Sans','font.size':12,'axes.titlesize':14,'axes.labelsize':12,'xtick.labelsize':11,'ytick.labelsize':11,'pdf.fonttype':42,'svg.fonttype':'none'})
records=[]; sources={}; cases={}
for i,layout in enumerate(['periodic','aperiodic'],1):
 run=f'mcf_20261003_224006_279_{i:02d}'; src=b.ROOT/'runs/pilot'/run
 cfg=json.loads((src/'config.json').read_text());t=loadmat(b.ROOT/'evaluation_only'/run/'mixed_truth.mat',simplify_cells=True)
 clean=loadmat(src/'mixed_clean_input.mat',simplify_cells=True); noisy=loadmat(src/'mixed_shot_read_input.mat',simplify_cells=True)
 mu=clean['amplitude']**2*noisy['camera']['exposure']; cam=noisy['camera']
 records.append({'layout':layout,'expected_sample_electrons':float(mu.sum()),'mean_sample_electrons':float(mu.mean()),'peak_sample_electrons':float(mu.max()),'negative_readout_fraction':cam['clipped_fraction'],'seed':cam['seed'],'exposure':cam['exposure']})
 for condition,d in [('clean',clean),('shot_read',noisy)]:
  case=f'{layout}_{condition}'; fields={'Truth':t['truth'],'Initial':d['mask']*d['calibration']}
  for method in ['HIO','ER','RAAR','LBFGS']:
   f=b.RUN/case/(method+'_result.mat');sources[str(f.relative_to(b.ROOT))]=hashlib.sha256(f.read_bytes()).hexdigest()
   snaps=loadmat(f,simplify_cells=True)['result']['snapshots'];snap=next(s for s in snaps if s['budget']==200);fields[method]=snap['physical_output']
   roi=t['roi'].astype(bool);u=fields[method];theta=np.angle(np.sum(np.conj(t['truth'][roi])*u[roi]));err=np.linalg.norm(u*np.exp(-1j*theta)-t['truth'])/np.linalg.norm(t['truth']);assert abs(err-b.metric(case,method,200))<1e-10
  cases[case]=(fields,t,d,cfg)
ampmax=max(float(np.abs(u).max()) for fields,_,_,_ in cases.values() for u in fields.values())
for case,(fields,t,d,cfg) in cases.items():
 roi=t['roi'].astype(bool);n=cfg['n'];dx=cfg['dx']*1e6;extent=[-n*dx/2,n*dx/2,n*dx/2,-n*dx/2]
 for kind in ['amplitude','phase']:
  if __import__('os').environ.get('FAST_REUSE_FIGURES') and (figdir/f'{case}_{kind}.pdf').exists(): continue
  fig,axs=plt.subplots(2,3,figsize=(10,7.2),layout='constrained')
  for j,(ax,(label,u)) in enumerate(zip(axs.flat,fields.items())):
   theta=np.angle(np.sum(np.conj(t['truth'][roi])*u[roi]));v=np.abs(u) if kind=='amplitude' else np.where(roi,np.angle(u*np.conj(d['calibration'])*np.exp(-1j*theta)),np.nan)
   im=ax.imshow(v,extent=extent,origin='upper',interpolation='nearest',cmap='viridis' if kind=='amplitude' else 'twilight_shifted',vmin=0 if kind=='amplitude' else -np.pi,vmax=ampmax if kind=='amplitude' else np.pi)
   ax.set(xlim=(-32,32),ylim=(32,-32),xticks=[-30,0,30],yticks=[-30,0,30],xlabel='x (µm)',ylabel='y (µm)',title=f'({chr(97+j)}) '+('L-BFGS' if label=='LBFGS' else label))
  cb=fig.colorbar(im,ax=axs,shrink=.86,pad=.025);cb.set_label('Field amplitude (relative units)' if kind=='amplitude' else 'Reference-corrected phase (rad)')
  if kind=='phase':cb.set_ticks([-np.pi,0,np.pi],labels=['−π','0','π'])
  for ext in ['pdf','svg','png']:fig.savefig(figdir/f'{case}_{kind}.{ext}',dpi=600 if ext=='png' else 150)
  plt.close(fig)
(figdir/'noise_audit.json').write_text(json.dumps(records,indent=2))
(figdir/'data_provenance.json').write_text(json.dumps({'sources_sha256':sources,'field_nrmse_checks':16,'shared_amplitude_max':ampmax,'display_extent_um':[-32,32],'raw_detector_shape':[256,256],'interpolation':'nearest'},indent=2))
# Keep conclusions; replace crowded figure pages and ambiguous noise wording.
b.pages=b.pages[:2]
b.pages[0]['items'][0]=('p','阶段汇报｜2026年10月4日修订｜呈佳伟老师')
b.pages[1]['items']=[x for x in b.pages[1]['items'] if not (x[0]=='p' and ('含噪声数据' in x[1] or '第3—6页' in x[1]))]
b.pages[1]['items'].insert(5,('p','两类布局使用同一混合样品、已知合成参考校准和共同初始化规则。噪声模型及本轮实际计数见下一页；第4—11页分别展示振幅与相位。'))
noise_table=[['布局','样品总期望电子','每像素均值','负读数比例']]+[[('周期' if r['layout']=='periodic' else '非周期'),f"{r['expected_sample_electrons']:.1f}",f"{r['mean_sample_electrons']:.3f}",f"{100*r['negative_readout_fraction']:.2f}%"] for r in records]
b.pages.append({'title':'噪声定义与本轮实际强度','landscape':False,'items':[
 ('h','从无噪声强度到求解器输入'),
 ('p','令 I_p 为探测器第 p 个像素的无噪声强度（细网格传播后进行像素平均），I_ref,p 为空白参考帧强度。曝光换算系数 α = 200000 / Σ_p I_ref,p，本轮两种布局均约为 50。'),
 ('p','散粒噪声：K_p ~ Poisson(μ_p)，μ_p = α I_p。读出噪声：ε_p ~ N(0, σ_r^2)，σ_r = 1 电子/像素（标准差）。两者独立，按像素独立采样。'),
 ('p','相机读数 Y_p = K_p + ε_p；非负处理 C_p = max(Y_p, 0)；输入振幅 A_p = sqrt(C_p / α)。无噪声对照直接使用 A_p = sqrt(I_p)。'),
 ('h','“20 万”的准确含义'),
 ('p','20 万指整个空白参考帧的总期望光电子数，定义曝光尺度。256 × 256 像素下，空白帧每像素平均为 3.052 电子；样品透射损耗使样品帧总期望计数降低。这里未单独建模量子效率，不能直接解释成入射光子数。'),
 ('table',noise_table),
 ('p','表中计数由保存的无噪声输入与曝光系数计算；负读数比例取自运行时相机记录，分母为全部 65536 个像素。两布局的峰值期望计数分别为 '+f"{records[0]['peak_sample_electrons']:.2f}、{records[1]['peak_sample_electrons']:.2f}"+' 电子/像素。'),
 ('h','噪声统计与比较边界'),
 ('p','截断前 E[Y_p] = μ_p，Var(Y_p) = μ_p + σ_r^2；因此散粒噪声随信号变化，不能用一个固定“百分比噪声”描述。负值截断会在暗区引入正偏，开方后也不再是加性高斯噪声。表中较高负读数比例包含大量暗像素。'),
 ('p','相机代码为 fast_mcf_camera.m（泊松乘积采样），随机生成器为 MATLAB twister，实际种子 3102027。四算法复用同一保存的含噪输入；两布局同种子不代表相同计数实现。每条件仅一次噪声实现，未给出跨噪声重复的置信区间。参考校准为已知合成复场，未另加校准误差。')
]})
for case,label in b.CASES:
 for kind in ['amplitude','phase']:
  title='振幅' if kind=='amplitude' else '相位'
  b.pages.append({'title':label+'｜'+title+'比较','landscape':True,'items':[
   ('image',figdir/f'{case}_{kind}.png',25.4,15.0),
   ('small',('六面板按真值、共同初值、HIO、ER、RAAR、L-BFGS 排列。四算法预算均为 200 次传播。坐标为端面位置；显示范围 ±32 微米，覆盖半径 29 微米支持域；完整网格宽 128 微米；所有振幅图共用色标，未逐图归一化。' if kind=='amplitude' else '参考校正相位为 arg[u · conj(u_ref) · exp(−iθ)]；θ 在评分 ROI 内对齐真值的一个全局相位。仅显示保存的亮芯 ROI，白色区域为未显示区域，不代表零相位。所有相位图统一为 [−π, π]。')),
  ]})
b.build_word();b.build_pdf();b.build_markdown()
# Replace report raster figure placements with original PDF panels: vector text/axes.
pdfpath=b.OUT/(b.STEM+'.pdf');doc=fitz.open(pdfpath)
for index,page in enumerate(doc):
 if index<3:continue
 png=next(x[1] for x in b.pages[index]['items'] if x[0]=='image');rect=page.get_image_rects(page.get_images()[0][0])[0]
 page.add_redact_annot(rect,fill=(1,1,1));page.apply_redactions()
 src=fitz.open(png.with_suffix('.pdf'));page.show_pdf_page(rect,src,0)
tmp=pdfpath.with_suffix('.tmp.pdf');doc.save(tmp,garbage=4,deflate=True);doc.close();tmp.replace(pdfpath)
with zipfile.ZipFile(b.OUT/'FAST_高清图源文件_20261004.zip','w',zipfile.ZIP_DEFLATED) as z:
 for p in sorted(figdir.iterdir()):z.write(p,p.name)
print(json.dumps({'report':b.STEM,'pages':len(b.pages),'noise':records,'amplitude_max':ampmax},ensure_ascii=False))
