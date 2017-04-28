# puppet-ec2tags
Implementation of a `role` fact via AWS.

This also adds a structured fact named `ec2_data`, which contains the complete tags of the EC2 instance.

In order to work, this requires the EC2 instace(s) to be in an IAM role allowing access to the tags, such as the AmazonEC2ReadOnlyAccess policy.

It also requires the `aws-sdk` gem to be installed within the puppet agent and puppetserver gems.
