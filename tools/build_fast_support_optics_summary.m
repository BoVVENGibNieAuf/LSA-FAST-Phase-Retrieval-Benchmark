function build_fast_support_optics_summary(out)
files=dir(fullfile(out,'*','*_curve.csv')); summary=table;
for j=1:numel(files)
 t=readtable(fullfile(files(j).folder,files(j).name),'TextType','string');
 [~,k]=min(t.field_nrmse); s=t(k,:); s.final_field_nrmse=t.field_nrmse(end);
 s.final_full_field_nrmse=t.full_field_nrmse(end); s.final_phase_rmse=t.phase_rmse(end);
 summary=[summary;s]; %#ok<AGROW>
end
writetable(summary,fullfile(out,'retrospective_best.csv'));
% Actual-run figures, never populated with expected results.
cases=unique(summary.case_name);
for j=1:numel(cases)
 f=figure('Visible','off'); hold on;
 for m={'HIO','ER','RAAR','LBFGS'}
  t=readtable(fullfile(out,cases(j),[m{1} '_curve.csv']));
  plot(t.iteration,t.field_nrmse,'DisplayName',m{1});
 end
 xlabel('Accepted iteration'); ylabel('Field NRMSE (fixed reference ROI)');
 title(cases(j),'Interpreter','none'); legend('Location','best'); grid on;
 exportgraphics(f,fullfile(out,cases(j),'iteration.png'),'Resolution',150); close(f);
end
end
