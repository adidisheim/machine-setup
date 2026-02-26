## CRITICAL SAFETY RULES

**NEVER delete anything under `/data/projects/punim2039/` on Spartan. Not alpha_odds, not anything else. This is irreplaceable research data. No `rm`, no overwrite, no truncation. This rule has no exceptions.**

It is OK to delete things in `/home/adidishe/` (scratch/home) on Spartan.

## Spartan HPC Operations

### Connection
```bash
ssh spartan    # Alias configured in ~/.ssh/config (user: adidishe)
```

### Three Ways to Run Code on Spartan
| Method | Command | Use for | ML libs available? |
|--------|---------|---------|-------------------|
| **Login node** | `ssh spartan "<cmd>"` | `ls`, `du`, `cat`, file ops | NO (bare Python 3.9) |
| **`srun` (interactive)** | `ssh spartan "cd /home/adidishe/<PROJECT> && srun --partition=interactive --time=00:10:00 --mem=16G bash -c 'source load_module.sh && python3 ...'"` | Quick debugging, data inspection, short analyses | YES |
| **`sbatch` (batch)** | `ssh spartan "cd /home/adidishe/<PROJECT> && sbatch script.slurm"` | Long-running jobs, parallelized processing | YES |

`srun` typically queues for 5-15 seconds then runs. For heavier interactive work, increase `--mem` and `--time`.
`load_module.sh` loads the full module stack + activates the venv.

### srun Contention — Fallback to sbatch

**Before using `srun`, check if the interactive partition is already in use:**
```bash
ssh spartan "squeue -u adidishe -p interactive"
```
- If there is already an `srun` job running (another Claude session or the user), **do NOT queue another `srun`** — it may hang or block the other session.
- Instead, fall back to `sbatch`: write your Python code to a temporary script, submit it via `sbatch`, and poll for results.

**Fallback pattern:**
```bash
# 1. Write the script
ssh spartan "cat > /home/adidishe/<PROJECT>/tmp_run.py << 'PYEOF'
<your python code here>
PYEOF"

# 2. Submit via sbatch (one-liner SLURM wrapper)
ssh spartan "cd /home/adidishe/<PROJECT> && sbatch --job-name=tmp_run --output=out/tmp_run_%j.out --time=00:10:00 --mem=16G --cpus-per-task=2 --wrap='source load_module.sh && python3 tmp_run.py'"

# 3. Monitor until done
ssh spartan "squeue -u adidishe -n tmp_run"

# 4. Read output
ssh spartan "cat /home/adidishe/<PROJECT>/out/tmp_run_<jobid>.out"
```

**Do not wait more than 30 seconds for an `srun` to start.** If it doesn't start promptly, cancel it and use `sbatch` instead. Never let a blocked `srun` stall your work.

### Directory Layout on Spartan
| Path | Purpose | Can delete? |
|------|---------|-------------|
| `/home/adidishe/<PROJECT>/` | Code + SLURM scripts (flat structure) | YES |
| `/home/adidishe/<PROJECT>/out/` | SLURM stdout/stderr logs | YES |
| `/data/projects/punim2039/<PROJECT>/data/` | Raw & processed data | **NEVER** |
| `/data/projects/punim2039/<PROJECT>/res/` | Results, models, features, reports | **NEVER** |

### Deploying Code
```bash
bash scripts/sh/code_to_spartan.sh   # scp all .py files + slurm scripts to Spartan
```
**Important:** On the server, all Python files from `_XX_` subdirectories are copied flat to `/home/adidishe/<PROJECT>/`. The subdirectory organization is local-only for development.

### Submitting SLURM Jobs
```bash
ssh spartan "cd /home/adidishe/<PROJECT> && sbatch <script>.slurm"
```

### Running Interactive Python on Spartan
The login node has bare Python 3.9 without pyarrow/pandas — **only use it for bash commands** (ls, du, file ops). For anything needing the ML stack, use `srun`:
```bash
# Quick interactive Python on a compute node (queues briefly, then runs)
ssh spartan "cd /home/adidishe/<PROJECT> && srun --partition=interactive --time=00:10:00 --cpus-per-task=2 --mem=16G bash -c 'source load_module.sh && python3 -c \"<code>\"'"

# For longer scripts, write to a .py file first, then:
ssh spartan "cd /home/adidishe/<PROJECT> && srun --partition=interactive --time=00:30:00 --cpus-per-task=4 --mem=32G bash -c 'source load_module.sh && python3 my_script.py'"
```

### Monitoring Jobs
```bash
ssh spartan "squeue -u adidishe"                                            # List running jobs
ssh spartan "tail -50 /home/adidishe/<PROJECT>/out/<job>.out"               # Check output
ssh spartan "scancel <job_id>"                                              # Cancel a job
```

### Downloading Results
```bash
scp spartan:/data/projects/punim2039/<PROJECT>/res/<file> ./res/
scp -r spartan:/home/adidishe/<PROJECT>/out/ ./spartan_logs/
```

### SLURM Module Stack
All SLURM scripts load: `foss/2022a`, `GCCcore/11.3.0`, `Python/3.10.4`, `cuDNN/8.4.1.50-CUDA-11.7.0`, `TensorFlow/2.11.0`, `PyTorch/1.12.1`. Venv: `~/venvs/alpha_odds_venv/bin/activate`.

For matplotlib (needed by report scripts): also `module load matplotlib/3.5.2`.

### CRITICAL WORKFLOW RULE: Always Validate Before Proceeding

**Before running ANY downstream step (model training, analysis, backtesting), ALWAYS:**
1. Verify ALL upstream SLURM jobs completed successfully (`squeue -u adidishe` shows no remaining tasks)
2. Run the merge/validation script for that stage if one exists
3. Check the validation output: correct row/column counts, no `_x`/`_y` duplicates, sane values
4. Only then submit the next stage's jobs

**Never assume jobs finished — always check. Never skip the merge step.**

### Key Technical Notes
- **No scipy on Spartan venv**: Use `from math import erf, sqrt` and `0.5*(1+erf(x/sqrt(2)))` for norm_cdf
- **matplotlib on Spartan**: Must `module load matplotlib/3.5.2` in addition to base stack for report scripts
- **Code deployed flat**: All Python files go to `/home/adidishe/<PROJECT>/` (no subdirectories on server)
- **Login node is bare**: Python 3.9 without pyarrow/pandas — only use for bash commands, use `srun` for anything else
