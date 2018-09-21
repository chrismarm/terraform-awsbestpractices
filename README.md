* Bastions
	* Security group for managed machines in private subnet (ingress from bastions SG)
* Auto Scaling Group for frontend
	* ELB for ASG
* Custom ACL
* NAT instances to allow private machines to be updated