# Cleanup Notes

## Duplicate VPC Incident (Resolved)

During early development, a duplicate VPC was unintentionally created before Terraform remote state was configured. This resulted in temporary infrastructure drift between Terraform state and AWS resources.

### Resolution

- Removed the duplicate VPC through the AWS Console after dependency analysis.
- Verified that no production resources were attached.
- Configured Terraform remote state to prevent future state divergence.
- Documented the root cause in the README under **Design Decisions**.

### Outcome

- No AWS charges were incurred.
- Infrastructure was successfully destroyed using `terraform destroy`.
- Verified a clean AWS environment with no remaining VPCs, ALBs, RDS instances, or EC2 resources.
