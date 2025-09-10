%% ---------------- CONFIGURATION ----------------
spm('defaults','fmri');
spm_jobman('initcfg');

folderPath = 'C:\Users\cjohn\Documents\CS4850\first_visits';
dirInfo = dir(folderPath);

% === List of subject T1 images (full paths) ===

subj_list = {};

for i = 1:length(dirInfo)
            subj_list{end+1} = fullfile(dirInfo(i).folder, dirInfo(i).name);
end

% === List of atlases (NIfTI files) ===
atlas_list = {
    'C:\Users\cjohn\Documents\CS4850\brain_templates\AAL.nii'
    'C:\Users\cjohn\Documents\CS4850\brain_templates\AAL2.nii'
    'C:\Users\cjohn\Documents\CS4850\brain_templates\AAL3v1_1mm.nii'
    'C:\Users\cjohn\Documents\CS4850\brain_templates\BN_Atlas_246_1mm.nii'
    'C:\Users\cjohn\Documents\CS4850\brain_templates\brodmann.nii'
    'C:\Users\cjohn\Documents\CS4850\brain_templates\Hammers_mith_atlas_n30r83_SPM5.nii'
    'C:\Users\cjohn\Documents\CS4850\brain_templates\HarvardOxford-sub-maxprob-thr25-1mm.nii'
    'C:\Users\cjohn\Documents\CS4850\brain_templates\Juelich-maxprob-thr25-1mm.nii'
};

% === Base output directory for results ===
base_outdir = 'C:\Users\cjohn\Documents\CS4850\results_multiatlas';

nproc = 1;  % number of cores for CAT12

%% ---------------- PIPELINE ----------------
for si = 1:numel(subj_list)
    subj_id = 'UNKNOWN';
    try
        % --- Subject info
        t1path = subj_list{si};
        [~, t1name, ~] = fileparts(t1path);
        subj_id = t1name;

        % --- Subject output folder
        outdir = fullfile(base_outdir, subj_id);
        if ~exist(outdir,'dir'), mkdir(outdir); end

        fprintf('\n=== Processing subject %s ===\n', subj_id);

        % --- Locate CAT12 outputs (mwp1*.nii). If found, skip segmentation
        t1dir = fileparts(t1path);
        mwp1_candidates = findFileRecursive(t1dir, 'mwp1*.nii', 2);

        if isempty(mwp1_candidates)
            fprintf('Running CAT12 segmentation for %s...\n', subj_id);
            matlabbatch = {};
            matlabbatch{1}.spm.tools.cat.estwrite.data = { [t1path ',1'] };
            matlabbatch{1}.spm.tools.cat.estwrite.nproc = nproc;
            matlabbatch{1}.spm.tools.cat.estwrite.opts.tpm = { fullfile(spm('Dir'),'tpm','TPM.nii') };
            spm_jobman('run', matlabbatch);

            % Search again after CAT12
            mwp1_candidates = findFileRecursive(t1dir, 'mwp1*.nii', 2);
            if isempty(mwp1_candidates)
                error('CAT12 failed: Cannot find mwp1 output for subject %s in %s', subj_id, t1dir);
            end
        else
            fprintf('Segmentation already exists for %s, skipping CAT12.\n', subj_id);
        end

        mwp1path = mwp1_candidates{1};

        % --- Process each atlas
        all_tables = {};
        for ai = 1:numel(atlas_list)
            atlas_path = atlas_list{ai};
            [~, atlas_name, ~] = fileparts(atlas_path);
            atlas_name = erase(atlas_name, '.nii'); % cleanup double extensions

            % --- Reslice atlas to subject GM space
            subj_atlas = fullfile(outdir, sprintf('r%s_%s.nii', atlas_name, subj_id));
            if ~exist(subj_atlas,'file')
                fprintf('Reslicing atlas %s for subject %s...\n', atlas_name, subj_id);
                matlabbatch = {};
                matlabbatch{1}.spm.spatial.coreg.write.ref = { [mwp1path ',1'] };
                matlabbatch{1}.spm.spatial.coreg.write.source = { [atlas_path ',1'] };
                matlabbatch{1}.spm.spatial.coreg.write.roptions.interp = 0; % nearest neighbor
                matlabbatch{1}.spm.spatial.coreg.write.roptions.wrap = [0 0 0];
                matlabbatch{1}.spm.spatial.coreg.write.roptions.mask = 0;
                matlabbatch{1}.spm.spatial.coreg.write.roptions.prefix = 'r';
                spm_jobman('run', matlabbatch);

                % Move resliced atlas into subject folder
                movefile(fullfile(fileparts(atlas_path), ['r' atlas_name '.nii']), subj_atlas);
            end

            % --- Load atlas + GM map
            V_atlas = spm_vol(subj_atlas);  A = spm_read_vols(V_atlas);
            V_mwp1  = spm_vol(mwp1path);   M = spm_read_vols(V_mwp1);
            if ~isequal(size(A), size(M)), error('Mask mismatch'); end

            % --- Extract ROI features
            labels = unique(A(:)); labels(labels==0 | isnan(labels)) = [];
            roi_vals = nan(1,numel(labels));
            col_names = cell(1,numel(labels));
            for li = 1:numel(labels)
                mask = (A==labels(li));
                roi_vals(li) = mean(M(mask), 'omitnan');
                col_names{li} = sprintf('%s_ROI%03d', atlas_name, labels(li));
            end

            % --- Create feature table
            T = array2table(roi_vals, 'VariableNames', matlab.lang.makeValidName(col_names));
            T = addvars(T, repmat({subj_id}, height(T), 1), 'Before',1, 'NewVariableNames','SubjectID');
            all_tables{ai} = T;

            % --- Save per-atlas CSV
            writetable(T, fullfile(outdir, sprintf('%s_%s_features.csv', subj_id, atlas_name)));
        end

        % --- Merge all atlas features into one subject-wide table
        Tmerged = all_tables{1};
        for ai = 2:numel(all_tables)
            Tmerged = outerjoin(Tmerged, all_tables{ai}, 'Keys','SubjectID','MergeKeys',true);
        end
        writetable(Tmerged, fullfile(outdir, sprintf('%s_allAtlases.csv', subj_id)));

        fprintf('Finished subject %s.\n', subj_id);

    catch ME
        fprintf('Error processing %s: %s\n', subj_id, ME.message);
        continue;
    end
end

%% ---------------- Helper function ----------------
function matches = findFileRecursive(baseDir, pattern, maxDepth)
    if nargin<3, maxDepth=3; end
    matches = {};
    if maxDepth<0 || ~exist(baseDir,'dir'), return; end
    d = dir(fullfile(baseDir,pattern));
    for k=1:numel(d)
        if ~d(k).isdir
            matches{end+1} = fullfile(baseDir,d(k).name); %#ok<AGROW>
        end
    end
    sub = dir(baseDir); sub=sub([sub.isdir]);
    for i=1:numel(sub)
        nm=sub(i).name;
        if strcmp(nm,'.')||strcmp(nm,'..'),continue;end
        matches=[matches; findFileRecursive(fullfile(baseDir,nm),pattern,maxDepth-1)]; %#ok<AGROW>
    end
end