import json

#read the json file terraform.tfstate
with open('terraform.tfstate') as json_file:
    state = json.load(json_file)

#get the list of resources in the state
resources = state['resources']

#get the list of resources with the specified type
def getResources(type):
    return [resource for resource in resources if resource['type'] == type]

#get a list of all id's in the internet_gateway.instances
def getIGids():
    return [resource['attributes']['id'] for resource in getResources('aws_internet_gateway')[0]['instances']]


#check if the internet_gateway_ids is in the routes['instances']
def checkIGInRoute():
    routes_withIG =[]
    for route in getResources('aws_route'):
        for instance in route['instances']:
            if instance["attributes"]["gateway_id"] in getIGids():
                routes_withIG.append(route)
    return routes_withIG

#check if the value of attribute["destination_cidr_block"] is equal to "0.0.0.0/0"
def checkDestinationCidrBlock(routes_withIG):
    routes_withOutbound0 = []
    for route in routes_withIG:
        for instance in route['instances']:
            if instance["attributes"]["destination_cidr_block"] == "0.0.0.0/0":
                routes_withOutbound0.append(route)
    return routes_withOutbound0

#get the list of route table associations from resources
def getRouteTableAssociations():
    return [resource for resource in resources if resource['type'] == 'aws_route_table_association']

#search for the route_table_ids from routes_withOutbound0 in the route_table_associations
def getSubnetIds(routes_withOutbound0):
    public_subnet_ids = []
    for route in routes_withOutbound0:
        for instance in route['instances']:
            for association in getRouteTableAssociations():
                for route_table_instance in association['instances']:
                    if instance["attributes"]["route_table_id"] == route_table_instance["attributes"]["route_table_id"]:
                        public_subnet_ids.append(route_table_instance["attributes"]["subnet_id"])
    return public_subnet_ids

#get the aws_security_group from the vpc_security_group_ids in the instances
def getSecurityGroups(machines):
    security_group = getResources('aws_security_group')[0]
    security_group_instance = security_group['instances'][0]
    for machine in machines:
        for instance in machine['instances']:
            if instance["attributes"]["vpc_security_group_ids"][0] == security_group_instance['attributes']['id']:
                return security_group

#check for ingress rules in the security_group
def checkIngressRules():
    security_group = getSecurityGroups(getResources('aws_instance'))
    for instance in security_group['instances']:
        for ingress_rule in instance['attributes']['ingress']:
            if ingress_rule['from_port'] == 22 and "0.0.0.0/0" in ingress_rule['cidr_blocks']:
                return security_group


#get resources of type aws_instance and check if the vpc_security_group_ids is the same as the id of security_group_with_ingress_0_22
def getPublicMachines(security_group_with_ingress_0_22):
    instances = []
    ec2_instances = getResources('aws_instance')
    for instance in ec2_instances:
        for instance_instance in instance['instances']:
            if instance_instance["attributes"]["vpc_security_group_ids"][0] == (security_group_with_ingress_0_22['instances'][0])['attributes']['id']:
                if instance_instance["attributes"]["public_ip"] != "":
                    if instance_instance["attributes"]["subnet_id"] in getPublicSubnets():
                        instances.append(instance)
    return instances

def getPublicSubnets():
    #Get the list of routes with internet gateway
    routes_withIG = checkIGInRoute()
    #filter this list of routes with routes that have destination cidr block 0.0.0.0/0
    routes_withOutbound0 = checkDestinationCidrBlock(routes_withIG)
    #get the list of subnet ids that are associated with these routes. These will be public subnets.
    public_subnet_ids = getSubnetIds(routes_withOutbound0)
    return public_subnet_ids


#get the security group with the inbound rule from 0.0.0.0 on port 22
security_group_with_ingress_0_22 = checkIngressRules()

#get machines which have this security group and have a public ip and are in a public subnet
public_machines = getPublicMachines(security_group_with_ingress_0_22)


#print instance ids of public machines
for machine in public_machines:
    for instance in machine['instances']:
        print("The ec2 instance with id: " + instance["attributes"]["id"] + " is public.")