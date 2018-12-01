FEATURES
* 2 public and 2 private subnets
* Bastions
	* Security group for managed machines in private subnet (ingress from bastions SG)
* Auto Scaling Group for frontend (public subnet) with an ELB

NEXT STEPS

* NAT gateway to allow private backend machines to access internet to be updated (NOT within free tier)
	* EIP + inside public subnet
	* In private subnet route table, default entry must be to the Id of the NAT GW
	* In backend SG, there must be an outbound rule allowing traffic
* Terraform modules for vpc, frontend and backend, although it is not essential as no different environments have been defined (prod, test) so there is no code reusability
* Run a simple http server in frontend servers to check ELB behaviour
* Counts to create backend instances
* Volumes, RDS and DynamoDB
* Custom ACL
