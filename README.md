############### Coalfire AWS Technical Challenge Oct 2025 - Ian Wilson ###############

####### Solution Overview
The goal of this challenge was to create a proof of concept AWS environment using Terraform. This setup showcases a basic 3 tier web application with networking, computing and a load balancer to support a simple web applcation.

The infrastructure is fully designed with Terraform to allow for consistent and repeatable deployments of resources to the cloud. the infrastructure currently includes:

    - A VPC to separate the subnets for the application, management and backend layers.
    - An IGW (internet gateway) to allow outbound connections and public access where it is needed.
    - A NAT Gateway to allow private subnets that need to reach the internet, the ability to do so (such as installing and updating Apache).
    - IAM Roles attached to the EC2s to allow for the principle of least priviledge and further secure the infrastructure.
    - Enabled Encryption for data at rest by using EBS volume encryption and using AWS Certificate Manager for data in transit.
    - A private application subnet for hosting EC2 instances that run Apache and are provisioned through user data.
    - A management subnet with a public EC2 instance that can SSH into the environment.
    - An ALB (Applcation Load Balancer) to distrubute the flow of traffic across multiple EC2s managed by an ASG (Auto Scaling Group)



####### Design Decisions and Assumptions
- A lot of the services or instance types were chosen based off the instructions from the technical challenge document or were chosen to keep costs in the free tier or at the very least keep it as minimal as possible.

- I attempted to put each of the core components in different modules, however I ultimately decided to leave all of the Terraform in one main.tf due to simplicity reasons and to not overcomplicate debugging as I incrementedly added in different features. I recognize the importance of modules however, in larger or long-term use environments where the environment will grow overtime. Modules can increase scalability and maintainability in those examples. 

- The region chosen for this challenge was us-east-1 as it seemed to be a solid choice for the nature of this challenge and has a lot of resources available.

- There was temporary internet access route initially created for the private subnet that needed to have apache installed, but it can be removed upon the creation of a NAT Gateway to prevent unnecessary exposure to the internet. NAT Gateways can increase cost, but ultimately help to achieve the goals of the 3 tier wep application.

- The IAM roles were created under the assumption that the EC2s only needed basic permissions.



####### Runbook-Style Notes
All Terraform resources successfully deployed:
- 1 VPC (10.1.0.0/16) with 3 subnets (App, Mgmt, Backend)
- 1 Internet Gateway + 1 NAT Gateway
- 1 Application Load Balancer with Target Group
- 1 Auto Scaling Group (2 EC2s running Apache)
- 1 Management EC2 with IAM Role + SSM Access

Verification:
- Terraform Apply completed without errors (see apply log)
- Private EC2s accessible via Session Manager from management instance
- ALB Target Group health checks = Healthy


##################################################################################


####### Operational Analysis of Infrastructure
- Security Gaps: 

    #1
    - The application subnet is currently using a temporary public route so that, during provisioning, that EC2 instance can install Apache. This is a problem because that will likely expose the subnet to external access during setup and does not align well with security best practices.

    Improvement Plan:
    - implement a NAT Gateway into the management subnet. This would be an ideal solution as it would allow traffic for any updates or installations to flow through the Internet Gateway (attached to the management subnet) and not lead to any potential exposure to the application subnet from inbound connections, as it should not be accesible from the internet at all.


    #2
    - There is no encryption for any data while it is at rest or while it is in transit for the EC2 instance. This could be problematic and opens the current infrastructure to sensitive data being intercepted or infiltrated in either the EC2, any load balancer traffic or other future add ons to the current setup. Encryption is important to have to maintain the security and privacy of things like config files or logs.

    Improvement Plan:
    - Enable EBS volume encryption to be on by default for all of the EC2 instances. That way all new EC2 instances will have encrytped root EBS volumes. Important to note however, it will only be for instances that get created after the update occurs. This means any currently existing infrastructure will not have those changes, but since no infrastructure has been applied yet, this is not too problematic. If something did need to be encrypted after its launched, you could perform snapshot replacement. To avoid the issue happening again in the future, I would have the account enable EBS encryption by default to avoid accidents where it is not on for any instance. 

    To handle encrypting data in transit, since the only data that really needs to be encrypted is when users hit the ALB. Given its current setup, it would appear that using AWS Certificate Manager to get the TLS certifcation and add an HTTPS listener to the ALB, from there I would redirect all the traffic from port 80 (HTTP, unsecure) to port 443 (HTTPS, secure). That would be a more efficient approach as that lets the ALB handle all the TLS encryption or decryption.

    #3
    - There are no IAM Roles or any sort of Least privilege policies. Since there are no roles attached to the EC2 instances, they are not able to access other services within AWS in a secure way. This could lead to unintential credential escalation or other security risks. 

    Improvement Plan:
    - Make an IAM role for the EC2 instances with minimal privilege necessary so it is in line with the principle of least privilege. This will allow for secure, temporary credentials without having to embed any kind of access keys into the infrastructure.


##################################################################################


    - Availability Issues:

    #1
    - Right now, there is not very much utilization of different availability zones. The application and management subnet are in the same availability zone, and that poses an availability risk. If that AZ were to go down, those servers would not be reachable and pose a major operation risk. 
    
    Improvement Plan:
    - Deploying the subnets and EC2 instances across more availability zones will increase availability and make the infrastructure more resilient to AZ outages.

    #2
    - There are no backups in place and if anything were to go down or break and data gets deleted, there is not easy way to recover that data quickly, which is a big operational risk. 
    
    Improvement Plan:
    - A simple solution to this would be including something such as snapshots for the EBS for any important data. In the event something happens, this makes it easier to recover.


    ##################################################################################


    - Cost Optimization:
    
    #1
    - There is no cost monitoring in place, so it will be hard to keep track of costs, especially if there is a budget you need to stay under.

    Improvement Plan:
    - Using something like "aws_budgets_budget" as a resource to use the cost visualization tool for different parts of the Infrastructure from AWS Cost Explorer. It will show status of a budget and provide forecasts of an estimate costs which allows for plans to optimization as you track your AWS usage.


    ##################################################################################

    - Operational Shortcomings:

    #1
    - There is no means of any kind of patch management for the EC2 instances, this is a problem because as the installed packages or operating system become outdated, it potentially will become vulnerable to known security exploits. This will compromise the system if its not frequently patched to cover vulnerabilities proactively. 

    Improvement Plan:
    - Using AWS Systems Manager Patch Manager, patches can be automated to update the EC2 instances OS or other software updates that may be needed. Recurring patches can be scheduled to make sure the EC2 is always up to date to be protected from current known vulnerabilities.

    #2
    - There is a lack of monitoring with the current Infrastructure setup, which means it will be challenging to keep any sort of tabs on any meaningful metrics to note for this setup. It cannot track any CPU usage or networking data which will make it hard to troubleshoot issues. No kind of failure detection, so if something goes down, no good way of finding out before it's a problem. There are not kind of audit logs, which is a poor security practice.

    Improvement Plan: 
    - enabling CloudWatch would be ideal, as it is a default AWS feature that will help to monitor useful metrics or data. It will keep track of the health of an instance so it can be addressed before users notice, and it can add alarms for different things to notify when something is not right. To maintain logs for the infrastructure, using something like CloudTrail is useful. It is another default feature of AWS and it will log all API calls so it can track Terraform commands or other console changes to cover who does what and when they do it. This will make the infrastructure auditable which is very important for security.

    ##################################################################################

    - Priority List:

    Overview:
    - For the priority in which I feel should be getting fixed first, as an overview I would focus on Security fixes first as the highest priority as these are the most compromising to the infrastructure. Once I am confident in the security, I would then optimize any operation shortcomings because if you cannot see any current issues with the infrastructure or apply any changes, then no matter how secure it is, it will degrade over time. I would focus on Availability next as this will add a lot of resiliency to the infrastructure and make it more effective at recovery in the event of something going down, but it is not as critical as the previous two. Lastly, I would optimize cost once the others have been addressed as it is not as critical as the other issues but it is nice to optimize where you can to fit a companies business needs and to make the infrastructure the best it can be.

    Specific fixes:
    1) I would implement the NAT Gateway first, to lockdown the subnet that should be private, but needs internet access to get Apache. This will make it no longer exposed and allow it to be truly private but also let it get Apache or other updates as needed.

    2) Next I would enable the encryption for data that is at rest or in transit. This will protect confidential information.

    3) Make IAM Roles to make sure that there is no priviledge escalation and credentials will not need to be hardcoded into the infrastructure.

    4) Add in CloudWatch and CloudTrail next now that the larger security risks have been addressed. This is important for getting real time insight and making the infrastructure auditable, which is crucial.

    5) Set up Patch Management to keep everything updated and reduce the chances of it becoming vulnerable as time goes on.

    6) Set up the subnets in multiple AZs. This will alleviate any availability concerns and increase the reliability of the infrastructure.

    7) Make automated snapshots for the EBS so that the infrastructure can recover quickly in the event of any outages.

    8) Add budget monitoring for cost optimization to keep tabs on the budget and usage, as well as future estimated usage costs.

    Of these changes, the ones that I will implement will be the first three listed since these are the largest security risks to the infrastructure.

    ##################################################################################

    ####### Runbook-Style Notes
    # Prerequisites: 
        - Terraform installed on the local machine
        - AWS CLI with proper IAM credentials that have the necessary permissions


    - How to deploy and operate the environment:
        - From the CLI, navigate to the directory of the Terraform configuration files and run these 3 commands:
        - terraform init    # initialize the Terraform files
        - terraform plan    # review the changes before applying them
        - terraform apply   # builds and deploys all the resources

        - if you wish to reverse the infrastructure then you can run: 
        - terraform destroy # destroys all resources in the Terraform config file

    - How to respond to an outage for an EC2 instance:
        - This infrastructure utilizes an Autoscaling Group (ASG).
        - In the event an EC2 goes down, the ASG will terminate the instance and launch a fresh one.
        - To verify the replacement, follow these steps:
            - on AWS, go to EC2 -> Autoscaling Group
            - check to see if the new instance is up and running and check its health
            - You can also check under "Load Balancers" → "Target Groups" to see if the new instance shows as   healthy
        - In most cases the instances should fix themselves.

    - In the event an S3 bucket is added, these are some steps to restore data if the bucket were deleted.
        - First see if the bucket had versioning on.
        - If it is, then you can recover the data from older versions of that bucket.
        
        - If it does not having versioning on:
        - You can restore the data from a backup copy (if saved elsewhere)
        - For best practices, keep versioning on for S3 buckets and add in MFA for deleting data on the bucket.


##################################################################################


    Resources Used: 
        Terraform on AWS: Ultimate Beginner guide
        1) https://youtu.be/RiBSzAgt2Hw?si=5ovWO0nn7o_H90pO


        Find different examples to implement for AWS 
        2) https://registry.terraform.io/ 


        AWS VPC: How to create a VPC in Terraform
        3) https://youtu.be/FNROFMpr1x8?si=37oLvK4U38j1RkV6- 


        Setup AWS ALB with ASG
        4) https://youtu.be/1m54kzfjGtM?si=ndcF2Hcz1AnDUjjn 


        Security Group Ingress
        5) https://docs.aws.amazon.com/AWSCloudFormation/latest/TemplateReference/aws-properties-ec2-securitygroup-ingress.html


        Scripting the installation of apache on ec2
        6) https://jatinlodhi.medium.com/automating-apache-web-server-deployment-with-terraform-and-ansible-on-aws-fe14da76f827

           https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/user-data.html

           https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/install-LAMP.html 


        Help for autoscaling group
        7) https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/launch_template 

           https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/autoscaling_group 


        snapshot replacement
        8) https://docs.aws.amazon.com/ebs/latest/userguide/ebs-encryption.html 


        Handling encryption of in transit data
        9) https://docs.aws.amazon.com/elasticloadbalancing/latest/application/create-https-listener.html

           https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lb_listener

           https://docs.aws.amazon.com/acm/latest/userguide/acm-overview.html 


        AWS Patch Manager
        10) https://docs.aws.amazon.com/systems-manager/latest/userguide/patch-manager.html


        Managing budgets with cost explorer
        11) https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/budgets_budget


        Understanding and using modules
        12) https://developer.hashicorp.com/terraform/language/modules

            https://spacelift.io/blog/what-are-terraform-modules-and-how-do-they-work


        Understanding target_group_arn
        13) https://www.reddit.com/r/Terraform/comments/1ca394l/what_should_be_set_for_target_group_arn_in_an/


        NAT Gateways
        14) https://docs.aws.amazon.com/vpc/latest/userguide/vpc-nat-gateway.html

            https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/nat_gateway


        Setting up encryption
        15) https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ebs_encryption_by_default
        

        IAM Role
        16) https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role

            https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment

            https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_instance_profile

        

            
