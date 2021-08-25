Hello Android maintainers,

Please find our answers below:
- What device did this issue occur on?
  - Android emulator using latest AOSP code.
- What version of Android did this issue occur on?
  - Android 11 and SDK version 30
- What Security Patch Level (Settings > About Phone) was this issue observed with?
  - ro.build.version.security_patch=2021-03-05
- Could you please provide us with the fingerprint of the device on which you have tested this issue? (NOTE: Though the issue you are submitting may not appear to be device specific, having a fingerprint helps with our investigation and improves your chances for reward.)
  - Android/sdk_phone_x86_64/emulator_x86_64:S/AOSP.MASTER/eng.root.20210816.215534:eng/test-keys


In addition, we want to highlight that we observe the same vulnerable code in the latest AOSP code. Regarding tests on real devices, we are working on getting new phones to evaluate if there are alternative exploitation interfaces (other than *create_sdp_record* in *btif_sdp_server.cc* as mentioned above). However, this would take some time. We will update this ticket if we identify new interfaces that can be used to exploit the integer overflow vulnerability.


Relevant source code links:
- The bluetooth stack: https://android.googlesource.com/platform/system/bt/+/refs/heads/master
- The vulnerable code that have integer overflow: https://android.googlesource.com/platform/system/bt/+/refs/heads/master/osi/src/allocation_tracker.cc#173
