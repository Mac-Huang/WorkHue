#!/usr/bin/env python3
import argparse, datetime, hashlib, json, pathlib, plistlib, subprocess, tempfile, time
ROOT=pathlib.Path(__file__).resolve().parents[2]
SOURCE=pathlib.Path(__file__).resolve().with_name('LifetimeProbeApp.swift')
PHONE=WATCH=EVIDENCE=None

def run(command):
    result=subprocess.run(command,text=True,capture_output=True)
    if result.returncode: raise RuntimeError(str(command)+'\n'+result.stdout+'\n'+result.stderr)
    return result.stdout.strip()
def load(path):
    try: return json.loads(path.read_text())
    except (FileNotFoundError,json.JSONDecodeError): return None

def wait_report(path,timeout):
    deadline=time.monotonic()+timeout
    report=None
    while time.monotonic()<deadline:
        report=load(path)
        if report and report.get('error'): raise RuntimeError(str(report))
        if report and report.get('finished'): return report
        time.sleep(.25)
    raise RuntimeError('Report timed out: '+str(path)+' '+str(report))

def trial(mode):
    print('Building '+mode,flush=True)
    stamp=datetime.datetime.now(datetime.timezone.utc).strftime('%Y%m%d%H%M%S')
    bundle='dev.codex.PunchinoLifetimeProbe.run'+stamp+('.retained' if mode=='retained' else '.short')
    watch_bundle=bundle+'.watchkitapp'
    build=pathlib.Path(tempfile.mkdtemp(prefix='punchino-widget-lifetime-'+mode+'-'))
    phone_app=build/'LifetimeProbe.app'
    watch_app=phone_app/'Watch'/'LifetimeProbeWatch.app'
    watch_app.mkdir(parents=True)
    shared=sorted((ROOT/'Shared').glob('*.swift'))
    hashes={p.name:hashlib.sha256(p.read_bytes()).hexdigest() for p in shared}
    base={'CFBundleExecutable':'LifetimeProbe','CFBundleName':'LifetimeProbe','CFBundleDisplayName':'Widget Lifetime Probe','CFBundlePackageType':'APPL','CFBundleShortVersionString':'1.0','CFBundleVersion':'1','MinimumOSVersion':'26.0','CloudSyncEnabled':False}
    phone_info=dict(base,CFBundleIdentifier=bundle,LSRequiresIPhoneOS=True,UIDeviceFamily=[1],UILaunchScreen={},UISupportedInterfaceOrientations=['UIInterfaceOrientationPortrait'])
    watch_info=dict(base,CFBundleIdentifier=watch_bundle,WKApplication=True,WKCompanionAppBundleIdentifier=bundle,WKRunsIndependentlyOfCompanionApp=True,UIDeviceFamily=[4])
    for app,info in [(phone_app,phone_info),(watch_app,watch_info)]: (app/'Info.plist').write_bytes(plistlib.dumps(info))
    entitlements=build/'empty.entitlements'
    entitlements.write_bytes(plistlib.dumps({}))
    for sdk_name,target,app in [('iphonesimulator','arm64-apple-ios26.0-simulator',phone_app),('watchsimulator','arm64-apple-watchos26.0-simulator',watch_app)]:
        sdk=run(['xcrun','--sdk',sdk_name,'--show-sdk-path'])
        command=['xcrun','swiftc','-parse-as-library','-swift-version','5','-sdk',sdk,'-target',target]
        if sdk_name=='watchsimulator': command+=['-D','PUNCHINO_WIDGET']
        command += [str(p) for p in shared]+[str(SOURCE),'-o',str(app/'LifetimeProbe')]
        run(command)
    for app in [watch_app,phone_app]: run(['codesign','--force','--sign','-','--entitlements',str(entitlements),str(app)])
    installed=[]
    try:
        for device,app,identifier in [(PHONE,phone_app,bundle),(WATCH,watch_app,watch_bundle)]:
            run(['xcrun','simctl','install',device,str(app)])
            installed.append((device,identifier))
        paths=[]
        for device,identifier in installed:
            container=pathlib.Path(run(['xcrun','simctl','get_app_container',device,identifier,'data']))
            paths.append(container/'Library'/'Application Support'/'WidgetLifetimeProbe')
        phone_path,watch_path=paths
        run(['xcrun','simctl','launch',WATCH,watch_bundle,'--receive'])
        run(['xcrun','simctl','launch',PHONE,bundle])
        received=wait_report(watch_path/'receive-report.json',50)
        initial_phone=load(phone_path/'observe-report.json')
        assert received['sessionID']==initial_phone['sessionID']
        assert len(received['initialSnapshot']['sessions'])==1
        print(mode+': received active '+received['sessionID'],flush=True)
        run(['xcrun','simctl','terminate',WATCH,watch_bundle])
        time.sleep(.5)
        run(['xcrun','simctl','launch',WATCH,watch_bundle,'--'+mode])
        stopped=wait_report(watch_path/(mode+'-report.json'),25)
        phone=load(phone_path/'observe-report.json')
        phone_snapshot=load(phone_path/'tracking.json')
        watch_snapshot=load(watch_path/'tracking.json')
        assert received['processID']!=stopped['processID']
        assert stopped['sessionID']==received['sessionID']
        assert stopped['stoppedSnapshot']['sessions'][0].get('end') is not None
        assert not stopped.get('error')
        assert hashes=={p.name:hashlib.sha256(p.read_bytes()).hexdigest() for p in shared}
        outcome={'queueAccepted':stopped.get('queueAccepted'),'barrierElapsedSeconds':stopped.get('barrierElapsedSeconds'),'syncStatus':stopped.get('syncStatus'),'mode':mode,'watchStoreReleased':stopped.get('storeReleased'),'watchActivationAtReturn':stopped.get('activationAtReturn'),'watchDelegateAtReturn':stopped.get('delegateAtReturn'),'watchActivationAfterWait':stopped.get('activationAfterWait'),'watchDelegateAfterWait':stopped.get('delegateAfterWait'),'watchEnded':watch_snapshot['sessions'][0].get('end') is not None,'phoneEnded':phone_snapshot['sessions'][0].get('end') is not None,'phoneObservedStop':phone['converged'],'sameSessionID':phone_snapshot['sessions'][0]['id']==watch_snapshot['sessions'][0]['id'],'differentWatchProcess':received['processID']!=stopped['processID'],'waitSeconds':15,'cloudEnabled':False,'sharedSourceSHA256':hashes,'phoneBundle':bundle,'watchBundle':watch_bundle}
        if mode in ['short-lived','retained']:
            assert stopped['queueAccepted'] is True, 'The stop was not queued'
            assert phone['converged'] and phone_snapshot['sessions']==watch_snapshot['sessions'], 'Stored session fields did not converge'
            assert stopped['storeReleased'] is (mode=='short-lived'), 'Unexpected store lifetime'
        if mode=='zero-timeout':
            assert stopped['barrierElapsedSeconds'] < .5, 'Zero-timeout call did not return promptly'
            assert watch_snapshot['sessions'][0].get('end') is not None, 'The local stop was lost'
            if not stopped['queueAccepted']: assert stopped['syncStatus']=='Saved locally · Paired sync pending'
        outcome['sharedSourcesUnchanged']=True
        outcome['probeSourceSHA256']=hashlib.sha256(SOURCE.read_bytes()).hexdigest()
        outcome['runnerSHA256']=hashlib.sha256(pathlib.Path(__file__).read_bytes()).hexdigest()
        outcome['xcodeVersion']=run(['xcodebuild','-version'])
        evidence=EVIDENCE/mode
        evidence.mkdir(parents=True,exist_ok=True)
        for name,data in [('receive-report',received),('stop-report',stopped),('phone-report',phone),('phone-snapshot',phone_snapshot),('watch-snapshot',watch_snapshot),('outcome',outcome)]: (evidence/(name+'.json')).write_text(json.dumps(data,indent=2,sort_keys=True)+'\n')
        print(json.dumps(outcome),flush=True)
        return outcome
    finally:
        for device,identifier in reversed(installed):
            subprocess.run(['xcrun','simctl','terminate',device,identifier],capture_output=True)
            subprocess.run(['xcrun','simctl','uninstall',device,identifier],capture_output=True)

if __name__=='__main__':
    parser=argparse.ArgumentParser(description='Test a fresh widget-style process with the actual Shared sync code.')
    parser.add_argument('--phone',required=True,help='Booted paired iPhone simulator UUID')
    parser.add_argument('--watch',required=True,help='Its booted paired Watch simulator UUID')
    parser.add_argument('--repository',type=pathlib.Path,default=ROOT)
    parser.add_argument('--evidence',type=pathlib.Path,required=True)
    parser.add_argument('--modes',nargs='+',choices=['short-lived','retained','baseline','zero-timeout'],default=['short-lived','retained','zero-timeout'])
    args=parser.parse_args()
    ROOT=args.repository.resolve()
    PHONE,WATCH,EVIDENCE=args.phone,args.watch,args.evidence.resolve()
    pairs=json.loads(run(['xcrun','simctl','list','pairs','--json']))['pairs']
    pair=next(p for p in pairs.values() if p['phone']['udid']==PHONE and p['watch']['udid']==WATCH)
    assert pair['phone']['state']=='Booted' and pair['watch']['state']=='Booted', 'Boot the existing pair before this test'
    results=[trial(mode) for mode in args.modes]
    (EVIDENCE/'results.json').write_text(json.dumps(results,indent=2,sort_keys=True)+'\n')
    print('DONE '+json.dumps([{k:r[k] for k in ['mode','watchStoreReleased','watchEnded','phoneEnded','phoneObservedStop']} for r in results]),flush=True)
