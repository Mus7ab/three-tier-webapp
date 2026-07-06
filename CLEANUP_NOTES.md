# Cleanup Notes

## RESOLVED: Duplicate VPC (vpc-080f45397e4fc4f18)
Created accidentally by CI before remote state was configured (Day 7 incident - see README "Design Decisions" for root cause). 
Successfully deleted via AWS Console on 2026-07-06. CLI-based deletion was blocked by an unclear dependency 
that the console's guided delete flow resolved cleanly. No cost was incurred (VPC/subnets/IGW only, no ALB/EC2/RDS).

## Final teardown
Full `terraform destroy` completed on 2026-07-06/07 - 22 resources destroyed, verified clean via AWS CLI 
(no VPC, no RDS, no load balancers remaining). Project infrastructure fully torn down; code and history preserved.
