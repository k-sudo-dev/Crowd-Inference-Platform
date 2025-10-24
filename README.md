# CrowdInference Platform

A decentralized network on Stacks blockchain where users collaboratively run distributed AI inference jobs, earning rewards based on compute contributed and output quality validated by oracles.

## Features

- Distributed inference job creation
- Worker submission and participation tracking
- Quality-based reward distribution
- Worker reputation and statistics
- Automated payment based on verification

## Smart Contract Functions

### Public Functions

- `create-inference-job` - Create job with model and input hashes
- `submit-inference` - Workers submit inference results
- `verify-submission` - Requester verifies and scores output quality
- `distribute-rewards` - Automated reward distribution by quality
- `close-job` - Finalize and close inference job

### Read-Only Functions

- `get-inference-job` - Retrieve job details by ID
- `get-submission` - Get submission with quality score
- `has-participated` - Check if worker submitted for job
- `get-worker-stats` - View worker's reputation metrics
- `get-next-job-id` - Get next available job ID

## Usage

Requesters post inference jobs with model and input data hashes. Workers process computations and submit results. Quality is verified and rewards distributed proportionally. Worker reputation builds over time.