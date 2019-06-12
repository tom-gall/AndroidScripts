#!/usr/bin/python

import sys, getopt
import xml.etree.ElementTree as ET
import json
import ndjson
from google.cloud import bigquery

board = 'HiKey'
android_ver = 'Android-9.0'

def parseXML(xmlfile, vintffile):
    # first we need to get the kernel and board information
    # make a new empty result list
    results = []
    # make a run dictionary 
    runinfo = {}
    buildinfo = {}

    with open(vintffile, 'r') as f:
        vintf_dict = json.load(f)
        kernel_version = vintf_dict['kernel_version']
        os_release = vintf_dict['os_release']


    tree = ET.parse(xmlfile)

    root = tree.getroot()

    # Result is the root element in VTS
    TestSuiteName = root.attrib['suite_name']
    TestSuiteVersion = root.attrib['suite_version']
    print (TestSuiteName, TestSuiteVersion)
    print ('\n')


    # make a new empty result list
    results = []
    # make a run list and then a runinfo dictionary 
    aRun = []
    runinfo = {}
    runinfo['testsuite'] = TestSuiteName
    runinfo['testsuite_version'] = TestSuiteVersion
    runinfo['kernel_version'] = kernel_version
    runinfo['full_kernel_version'] = os_release
    runinfo['os_release'] = os_release
    runinfo['git_repo'] = 'https://github.com/tom-gall/hikey-linaro.git'
    runinfo['git_branch'] = 'android-' + kernel_version + '-p-hikey'
    runinfo['start_time'] = root.attrib['start_display']
    runinfo['end_time'] = root.attrib['end_display']
    aRun.append(runinfo)
    buildinfo['compiler'] = 'clang'
    buildinfo['compiler_version'] = ''

    # runinfo['kernel_config'] = ''
    # runinfo['rundate'] = ''
    # runinfo['target_hw'] = 'Hikey'
    # OS under test
    # Host OS

    for module in root:
        # example : Module name="VtsKernelProcFileApi" abi="arm64-v8a" runtime="144931" done="true" pass="64"

        if module.tag == 'Build':
            runinfo['target'] = module.attrib['build_board']
            runinfo['target_os'] = 'Android ' + module.attrib['build_version_release']

        if module.tag == 'Module':
            CurrentABI = module.attrib['abi']
            CurrentModule = module.attrib['name']

            for testcase in module:

                for result in testcase:
                    # make a new dictory per object, include the run info in each object (yes this is weird
                    # BD databases want this over linking tables with id fields
                    Test = {}
                    Test['module'] = CurrentModule
                    Test['abi'] = CurrentABI
                    Test['result'] = result.attrib['result']
		    Test['testsuite'] = runinfo['testsuite']
                    Test['kernel'] = runinfo['os_release']
		    if Test['result'] == 'fail':
                        for failure in result:
                            Test['message'] = failure.attrib['message']
               #             for stacktrace in failure:
               #                 Test['stacktrace'] = stacktrace.attrib['StackTrace']
                    else:
                        Test['message'] = ""
                    Test['name'] = result.attrib['name']
               #    Test['run_info'] = runinfo
                    print (Test)
                    results.append(Test)
         


        # example : Module name="VtsKernelProcFileApi" abi="arm64-v8a" runtime="144931" done="true" pass="64"

    return results, aRun


def savetoCSV (items, filename):
    fields = ['module','abi','result', 'name']

    with open(filename, 'w') as csvfile:

       writer = csv.DictWriter(csvfile, fieldnames = fields)
       writer.writeheader()
       writer.writerows(items)


def savetoJSON (items, filename):
    with open(filename, 'w') as outfile:
        ndjson.dump(items,outfile)

def saveRunInfoToJSON(runinfo):
    with open('keystone.json', 'w') as outfile:
        ndjson.dump(runinfo,outfile)

def main():
   vintffile = ''
   xmlresultsfile = ''
   runinfo = ''
   outputfile = 'out.json'


   argv = sys.argv[1:]

   try:
       opts, args = getopt.getopt(argv, "hx:v:o:", ["xmlresults=", "vintffile=", "out="])
   except getopt.GetoptError:
       print 'convert-vts-xml2csv.py -x <xml result file> -v <Vint file> -o <output NSJSON>'
       sys.exit(2)
   for opt, arg in opts:
       if opt == '-h':
           print 'convert-vts-xml2csv.py -x <xml result file> -v <Vint file> -o <output NSJSON>'
       elif opt in ("-x", "xmlresults="):
           xmlresultsfile=arg 
       elif opt in ("-v", "vintffile="):
           vintffile=arg 
       elif opt in ("-o", "out="):
           outputfile = arg
 

   newresults, runinfo = parseXML(xmlresultsfile, vintffile)
   savetoJSON(newresults, outputfile)
   saveRunInfoToJSON(runinfo)

if __name__ == "__main__":
    main()
