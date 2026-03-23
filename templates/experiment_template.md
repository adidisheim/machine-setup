# Experiment: [SHORT TITLE]

**Date**: YYYY-MM-DD
**Status**: [running / complete / failed]

## Motivation

Why did we run this? What hypothesis are we testing?

## Setup

- **Data source**: [Reuters / DJ / Combined / Mistral]
- **Training data**: [individual articles / stock-month averages]
- **Eval pipeline**: [Pipeline A (avg→SAE) / Pipeline B (SAE→avg)]
- **Model type**: [Standard SAE / TopK SAE / Economic AE / ...]
- **Hidden dim**:
- **Grid**: [list of hyperparameters varied]
- **Train period**: [e.g. pre-2013]
- **Eval period**: [e.g. post-2014]

## Results

| Config | Post Sharpe | Full Sharpe | L0 |
|--------|------------|------------|-----|
|        |            |            |     |

## Findings

What did we learn?

## Next Steps

What does this suggest trying next?

## Code Files

List of scripts used (copied in `code/` subfolder):
- `_02_XX_train_*.py` — training
- `_02_XX_msrr_*.py` — evaluation
- `parameters.py` — relevant config section
