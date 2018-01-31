#!/usr/bin/env python2.7

import argparse
import calendar
import json
import sys
import datetime
import time
import urllib
import re
from subprocess import Popen, PIPE

# use curl/grep to get placement group instances
def get_instances_for_placement_groups(url):
  cmd = "curl -s {0} | grep -o '<\\(code\\).*</\\1>' | egrep -o ".format(url) +\
        "'\\w{2,3}\\.\\w{5,}' | grep -v amazon"
  popen_proc = Popen(cmd, shell=True, stdout=PIPE, stderr=PIPE)
  proc_out, proc_err = popen_proc.communicate()
  if popen_proc.wait() != 0:
    sys.stderr.write("Command failed! {0}\n".format(cmd))
    sys.stderr.write("Stdout:\n")
    sys.stderr.write(proc_out)
    sys.stderr.write("Stderr:\n")
    sys.stderr.write(proc_err)
    sys.exit(1)
  return proc_out

# use curl/jq to get a json array of instances/prices from aws
def get_instances_for_region(url, region):
  cmd = ("curl -s {0} | sed -e '/^[ /]\*.*/d' -e '/^callback(/d' -e '/^);/d'" +\
        " | jq '.config.regions[]  | select(.region == \"{1}\") | " + \
        " .instanceTypes[].sizes | map(with_entries(select(.key != " + \
        " \"valueColumns\")) + (.valueColumns[0].prices))'" + \
        " | jq -s add").format(url, region)
  popen_proc = Popen(cmd, shell=True, stdout=PIPE, stderr=PIPE)
  proc_out, proc_err = popen_proc.communicate()
  if popen_proc.wait() != 0:
    sys.stderr.write("Command failed! {0}\n".format(cmd))
    sys.stderr.write("Stdout:\n")
    sys.stderr.write(proc_out)
    sys.stderr.write("Stderr:\n")
    sys.stderr.write(proc_err)
    sys.exit(1)
  return json.loads(proc_out)

# get an array of instances for a region
def get_instances(region, burst):
  ci = get_instances_for_region(CURRENT_GEN_URL, args.region)
  pi = get_instances_for_region(PREVIOUS_GEN_URL, args.region)
  if ci is None:
    sys.stderr.write("Unable to find any instance for region!\n")
    sys.exit(1)
  insts = ci + pi
  for i in insts:
    if i['size'] in TINY_INSTS:
      i['vCPU'] = TINY_INSTS[i['size']]
      if burst == True:
        i['vCPU'] = TINY_INSTS[i['size']]
      else:
        i['vCPU'] = -1
  return insts

# get spot price history for a region/AZ/instances and time range
def get_spot_price_history(region, availability_zone, instances, start_offset
                           , end_offset):
  az_arg = ""
  if availability_zone:
    az_arg = " --availability-zone {0}".format(availability_zone)
  now_date = datetime.datetime.utcnow()
  start_date = (now_date + datetime.timedelta(hours=start_offset)).strftime('%Y-%m-%dT%H:%M:%SZ')
  end_date = (now_date + datetime.timedelta(hours=end_offset)).strftime('%Y-%m-%dT%H:%M:%SZ')

  cmd = ("aws ec2 --region {0} describe-spot-price-history --query " + \
        "'SpotPriceHistory[]' --product-descriptions 'Linux/UNIX (Amazon VPC)'"+\
        " --instance-types {1} --start-time {2} --end-time {3}").format(
        region, ' '.join(instances), start_date, end_date)
  cmd = cmd + az_arg
  popen_proc = Popen(cmd, shell=True, stdout=PIPE, stderr=PIPE)
  proc_out, proc_err = popen_proc.communicate()
  if popen_proc.wait() != 0:
    sys.stderr.write("Command failed! {0}\n".format(cmd))
    sys.stderr.write("Stdout:\n")
    sys.stderr.write(proc_out)
    sys.stderr.write("Stderr:\n")
    sys.stderr.write(proc_err)
    sys.exit(1)
  return json.loads(proc_out)

CURRENT_GEN_URL = "https://a0.awsstatic.com/pricing/1/ec2/linux-od.js"
PREVIOUS_GEN_URL = "https://a0.awsstatic.com/pricing/1/ec2/" + \
                   "previous-generation/linux-od.js"
SPOT_PRICING_URL = "https://spot-price.s3.amazonaws.com/spot.js"
PG_URL = "https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/" + \
         "placement-groups.html"

TINY_INSTS = { 't1.micro': '0.1', 't2.nano': '0.05', 't2.micro': '0.10'
             , 't2.small': '0.2', 't2.medium': '0.4', 't2.large': '0.6'}

# instances that only support PV and not HVM virtualization
PV_INSTS = { 't1.micro': '', 'cg1.4xlarge': '', 'm2.xlarge': ''
           , 'm2.2xlarge': '', 'm2.4xlarge': '', 'c1.medium': ''
           , 'c1.xlarge': '', 'm1.small': '', 'm1.medium': '', 'm1.large': ''
           , 'm1.xlarge': ''}

parser = argparse.ArgumentParser(
         description="Find best spot priced instance/AZ combination.")

parser.add_argument("--region", default="us-east-1"
                   , help="AWS Region to check prices for.")
parser.add_argument("--availability_zone"
                   , help="AWS Availability Zone to check prices for " + \
                     "(defaults to all in region).")
parser.add_argument("--cpus", type=float, default=0.05
                   , help="# of CPUs required in the instance. Default: 0.05")
parser.add_argument("--mem", type=float, default=0.5
                   , help="Amount of memory (in GB) required in the instance. Default: 0.5")
parser.add_argument("--no-burst", dest='burst', default=True, action="store_false" 
                   , help="Don't use burstable instances (t1.*, t2.*).")
parser.add_argument("--instance_type"
                   , help="Specific instance type to use.")
parser.add_argument("--no-spot", dest='spot', default=True, action="store_false" 
                   , help="Don't use spot pricing.")
parser.add_argument("--spot-bid-factor", type=float, default=1.25
                   , help="Percentage of maximum historical price to bid" + \
                    " (automagically capped at instance on-demand price). Default: 1.25")


args = parser.parse_args()

# confirm it's a valid AZ
if args.availability_zone:
  cmd = ("aws ec2 --region {0} describe-availability-zones  --query " + \
        "'AvailabilityZones[*].ZoneName' --output text --zone-names " + \
        "{1}").format(args.region, args.availability_zone)
  popen_proc = Popen(cmd, shell=True, stdout=PIPE, stderr=PIPE)
  proc_out, proc_err = popen_proc.communicate()
  if popen_proc.wait() != 0:
    sys.stderr.write(
      "Invalid Availability Zone: {0}\n".format(args.availability_zone) )
    sys.exit(1)


# get all instances for region
instances = get_instances(args.region, args.burst)

valid_instances = []

# find all instances that satisfy cpu/mem requirements and support HVM
for i in instances:
  if float(i['vCPU']) >= args.cpus and float(i['memoryGiB']) >= args.mem \
  and i['size'] not in PV_INSTS:
    if not args.instance_type:
      valid_instances.append(i['size'])
    elif i['size'] == args.instance_type:
      valid_instances.append(i['size'])

if len(valid_instances) == 0:
  sys.stderr.write(
    "No valid instances available for requested constraints!\n" )
  sys.exit(1)


cheapest_instance = { 'Price': 9999, 'InstanceType': "INVALID"
                    , 'AvailabilityZone': "INVALID", 'Spot': "UNKNOWN"
                    , 'PlacementGroup': False, 'CurrentPrice': 9999 }

if args.instance_type not in TINY_INSTS and args.spot:
  # get current spot prices
  current_spot_prices = get_spot_price_history(args.region
                , args.availability_zone, valid_instances, 0, 0)

  # find cheapest spot price based valid instance
  for sp in current_spot_prices:
    if float(sp['SpotPrice']) < cheapest_instance['Price']:
      cheapest_instance['Price'] = float(sp['SpotPrice'])
      cheapest_instance['CurrentPrice'] = float(sp['SpotPrice'])
      cheapest_instance['InstanceType'] = sp['InstanceType']
      cheapest_instance['AvailabilityZone'] = sp['AvailabilityZone']
      cheapest_instance['Spot'] = True

# see if a cheaper regular on-demand instance suffices
for i in instances:
  if i['USD'] != 'N/A' and \
  float(i['USD']) < cheapest_instance['Price'] \
  and i['size'] in valid_instances:
    cheapest_instance['Price'] = float(i['USD'])
    cheapest_instance['CurrentPrice'] = float(i['USD'])
    cheapest_instance['InstanceType'] = i['size']
    cheapest_instance['AvailabilityZone'] = 'ANY'
    cheapest_instance['Spot'] = False

for i in instances:
  if i['size'] == cheapest_instance['InstanceType']:
    cheapest_instance['OnDemandPrice'] = float(i['USD'])

pg_instances = get_instances_for_placement_groups(PG_URL)
pg_output = "ci_pg=is not using placement groups#"

if cheapest_instance['InstanceType'] in pg_instances:
  cheapest_instance['PlacementGroup'] = True
  pg_output = "ci_pg=is using placement groups#pg_arg=-var placement_group=wallaroo-$(cluster_name)#"

# if cheapest instance is a spot instance
if cheapest_instance['Spot']:
  # get last 6 hours of prices for cheapest instance type
  last6_spot_prices = get_spot_price_history(args.region
               , cheapest_instance['AvailabilityZone']
               , [cheapest_instance['InstanceType']], -6, 0)

  # get 12 hours of priving from a week ago
  weekago_spot_prices = get_spot_price_history(args.region
               , cheapest_instance['AvailabilityZone']
               , [cheapest_instance['InstanceType']], -174, -162)

  max_price = cheapest_instance['Price']

  # find maximum price based on last 6 hour spot pricing
  for sp in last6_spot_prices:
    if float(sp['SpotPrice']) > max_price:
      max_price = float(sp['SpotPrice'])

  # find maximum price based on 12 hours a week ago spot pricing
  for sp in weekago_spot_prices:
    if float(sp['SpotPrice']) > max_price:
      max_price = float(sp['SpotPrice'])

  # set bid price to be maximum price found times spot-bid-factor
  bid_price = max_price * args.spot_bid_factor

  # cap bid price to on-demand price on high end
  if bid_price > cheapest_instance['OnDemandPrice']:
    bid_price = cheapest_instance['OnDemandPrice']

  # cap bid price to current spot price on low end
  if bid_price < cheapest_instance['CurrentPrice']:
    bid_price = cheapest_instance['CurrentPrice']

  cheapest_instance['Price'] = bid_price

  # output makefile fragment for make to eval
  print (pg_output + "ci_current_price={0}#".format(\
         cheapest_instance['CurrentPrice']) + \
        "ci_inst_type={0}#ci_inst_price={1}#ci_az={2}#availability_zone={2}" +\
        "#ci_args=-var leader_instance_type={0} -var follower_instance_type" +\
        "={0} -var 'leader_spot_price=\"{1}\"' -var 'follower_spot_price=\"" + \
        "{1}\"'").format(cheapest_instance['InstanceType']
        , cheapest_instance['Price'], cheapest_instance['AvailabilityZone'])

else:
  az_output = ""
  if args.availability_zone:
    az_output = "ci_az={0}#availability_zone={0}#".format(args.availability_zone)
  # output makefile fragment for make to eval if not spot instance
  print (pg_output + az_output + \
        "ci_inst_type={0}#ci_args=-var leader_instance_type={0} -var " + \
        "follower_instance_type={0}").format(cheapest_instance['InstanceType'])


