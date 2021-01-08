# multi-tier-aws-infra-using-terraform
Infrastructure as a code for building 2-tier [Web &amp; DB] on AWS using terraform

We could be first creating VPC [MY_VPC], further we will breakdown in two segments. APP_Subnet and DB_Subnet. 
Inside App_Subnet, we will be going to host App server [WebServer1] and in DB_Subnet, we will host db server [DBServer1].

Then, we will be creating an Internet Gateway [MY_IGW] which will be mapped to MY_VPC.
Post this, we will be launching our Routing table, so that WebServer1 would be having connectivity towards Internet. In Routing table, there would be default route pointing to Internet Gateway, then we will be attaching routing table to app subnet to establish the association. The moment we would establish this association, app subnet would be connecting towards Internet. Any server, we would be launching inside this app subnet would be having reachability towards Internet. 

After this, we would also need communication in-between subnets which are present inside VPC. So, the moment we would create VPC, there would be main default routing table would be also get created, which takes care of local routing. This will be associated to db subnet.

For security of Web or DB servers, we would be launching Security Groups [SG], where we would be going to define different ports which need to be opened to outside world. E.g. Internet users are going to use access our webserver on port 80 or 443. So, all those ports, we would be going to define in SG, wrt to app subnet, we would be going to create subnet as App_SG which would be attached to the neck of WebServer1, similarly we would be having setup for DB server. This would be architecture of this Multi-Tier Architecture.

