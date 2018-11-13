#!/usr/bin/python

import sys
import urllib2
import xml.etree.ElementTree as ET

cts_test_result_files = {
    '4.4': 'http://people.linaro.org/~tom.gall/Android-9/4.4-hikey/2018.11.12_14.29.25/test_result.xml',
    '4.9': 'http://people.linaro.org/~tom.gall/Android-9/4.9-hikey/2018.11.05_17.41.35/test_result.xml',
    '4.14': 'http://people.linaro.org/~tom.gall/Android-9/4.14-hikey/2018.11.09_12.46.13/test_result.xml',
    }

vts_test_result_files = {
    '4.4': 'http://people.linaro.org/~tom.gall/Android-9/4.4-hikey/2018.11.12_16.26.19/test_result.xml',
    '4.9': 'http://people.linaro.org/~tom.gall/Android-9/4.9-hikey/2018.11.07_14.55.33/test_result.xml',
    '4.14': 'http://people.linaro.org/~tom.gall/Android-9/4.14-hikey/2018.11.09_14.57.12/test_result.xml',
    }


def collect_failures(test_result_files={}):
    failures = {}
    for kernel, ref_url in test_result_files.items():
        response = urllib2.urlopen(ref_url)
        print 'Trying to parse now: %s' % ref_url
        parse_failures(content=response.read(), kernel=kernel, ref_url=ref_url, failures=failures)
        print 'Finished parsing: %s' % ref_url

    return failures

def parse_failures(content='', kernel='', ref_url='', failures={}):
    '''
        collect the failures information from the information provided by content,
        where the content is from the cts test_result.xml
    '''
    try:
        root = ET.fromstring(content)
        for elem in root.findall('Module'):
            abi = elem.attrib['abi']
            if 'abi' in elem.attrib.keys():
                abi = elem.attrib['abi']
            else:
                abi = None

            module_name = elem.attrib['name']

            test_cases = elem.findall('.//TestCase')
            for test_case in test_cases:
                testcase_name = test_case.get("name")
                failed_tests = test_case.findall('.//Test[@result="fail"]')
                for failed_test in failed_tests:
                    test_name = failed_test.get("name")
                    module_testcase_test = '%s %s#%s' % (module_name, testcase_name, test_name)
                    stacktrace = failed_test.find('.//Failure/StackTrace').text
                    failure = failures.get(module_testcase_test)
                    if failure:
                        if not abi in failure.get('abis'):
                            failure.get('abis').append(abi)
                        if not kernel in failure.get('kernels'):
                            failure.get('kernels').append(kernel)
                        if not ref_url in failure.get('ref_urls'):
                            failure.get('ref_urls').append(ref_url)
                    else:
                        failures[module_testcase_test] = {
                            'module_name': module_name,
                            'test_name': test_name,
                            'testcase_name': testcase_name,
                            'stacktrace': stacktrace,
                            'abis': [ abi ],
                            'kernels': [ kernel ],
                            'ref_urls': [ ref_url ],
                                                }

    except ET.ParseError as e:
        print('xml.etree.ElementTree.ParseError: %s' % e)
        print('Please Check %s manually' % ref_url)
        sys.exit(1)

    return failures

def file_bugs(failures={}):
    for module_testcase_test, failure in sorted(failures.items()):
        if failure.get('module_name') == failure.get('testcase_name'):
            title = '%s#%s' % (failure.get('testcase_name'), failure.get('test_name'))
        else:
            title = module_testcase_test

        short_desc = '%s %s %s: %s' % ( board,
                                   android_ver,
                                   ' '.join(failure.get('kernels')),
                                   title,
                                   )
        #print short_desc
        #continue

        new_file_bug_url = '%s%s' % (file_bug_url, '&short_desc=%s' % short_desc)
        print '%s\n' % new_file_bug_url
        print 'StackTrace:\n%s\n' % failure.get('stacktrace')
        print 'Abis:\n%s\n' % ' '.join(failure.get('abis'))
        print 'Kernels:\n%s\n' % ' '.join(failure.get('kernels'))
        print 'Reference Urls:\n%s\n' % '\n'.join(failure.get('ref_urls'))
        print '=========================='

    print 'There are totally %d bugs filed' % (len(failures))


board = 'HiKey'
android_ver = 'Android-9.0'
# https://bugs.linaro.org/enter_bug.cgi?product=Linaro%20Android&op_sys=Android&bug_severity=normal&component=R-LCR-X15&keywords=LCR&rep_platform=BeagleBoard-X15&short_desc=X15:%20linaro-android-kernel-tests
file_bug_url = ('https://bugs.linaro.org/enter_bug.cgi?'
                'product=Linaro%20Android'
                '&op_sys=Android'
                '&bug_severity=normal')
file_bug_url = '%s%s' % (file_bug_url, '&component=%s' % 'General')
file_bug_url = '%s%s' % (file_bug_url, '&version=%s' % 'PIE-9.0')
file_bug_url = '%s%s' % (file_bug_url, '&keywords=%s' % 'lkft')
file_bug_url = '%s%s' % (file_bug_url, '&rep_platform=%s' % 'HiKey')

def main():
    failures = collect_failures(cts_test_result_files)
    print "#### Info used for filing bugs started ###################"
    file_bugs(failures)
    print "#### Total bugs: %d ##################" % (len(failures))
    failures = collect_failures(vts_test_result_files)
    print "#### Info used for filing bugs started ###################"
    file_bugs(failures)
    print "#### Total bugs: %d ##################" % (len(failures))

if __name__ == "__main__":
    main()
