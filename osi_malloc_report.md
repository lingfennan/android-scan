[After reading the following instructions please enter the report details and attach applicable files]

*** This form is for reporting security bugs found in the Android Platform ***

*** A complete bug report must reproduce on the latest release of a supported Android branch, and should include applicable items as listed in:

https://sites.google.com/site/bughunteruniversity/improve/how-to-submit-an-android-platform-bug-report 

*** If this security issue qualifies for a fix to be included in security bulletin, we'd like to recognize your contribution. Please let us know how you would like your name and information to appear.

*** Submitted CTS tests and patches must apply cleanly to AOSP's master branch, comply with Coding Style Guidelines, and be accepted by Android Engineering as the most appropriate  fix.

*** If this report meets the rewards criteria, the reward amount will depend on the severity of the vulnerability and the quality of the report. 

Bugs filed using this form will be visible to the bug reporter, Google Android developers, and where appropriate Android hardware partners. Once the bug has been evaluated or resolved, it may become publicly accessible. Please do not include sensitive information that you do not want to become public.

Android Security Bugs and Severity Guidelines
http://source.android.com/devices/tech/security/overview/updates-resources.html#report-issues 

Android Vulnerability Rewards Program
https://www.google.com/about/appsecurity/android-rewards/



==============================================================================



This issue is related to Fluoride Bluetooth stack in Android, which is located at **system/bt** in AOSP.  The description of stack can be found at Android documentation at [Android Bluetooth](https://source.android.com/devices/bluetooth). Source code for the stack is available [here](https://android.googlesource.com/platform/system/bt/+/refs/heads/master).

Issue is in the function `allocation_tracker_resize_for_canary` in the file [system/bt/osi/src/allocation_tracker.cc](https://android.googlesource.com/platform/system/bt/+/refs/heads/master/osi/src/allocation_tracker.cc#173), see the code definition below:

```
172 size_t allocation_tracker_resize_for_canary(size_t size) {
173   return (!enabled) ? size : size + (2 * canary_size);
174 }
175
```
In the same file at line 40 `canary_size` is defined to constant size of 8:
```
40 static const size_t canary_size = 8;
```

At line 173, if `enabled` is set to be true (or 1 in C language) `size` in the function could lead to integer overflow. `enabled` is set to true in most recent Android Bluetooth stack.

Let's say maximum integer value possible to be stored in `size_t` is `MAX_SIZE_T`. `size_t` is an unsigned integer, at least of 16 bits but it's actual value is platform dependent, i.e. it's going to be maximum value stored in unsigned int on 32 bit platform (0xFFFFFFFF) and unsigned long on 64 bit platform (0xFFFFFFFFFFFFFFFF). In the function `allocation_tracker_resize_for_canary` if passed `size` is between MAX_SIZE_T - 16 <= size <= MAX_SIZE_T, then `allocation_tracker_resize_for_canary` will return size between 0 - 16. 

`allocation_tracker_resize_for_canary` is used in malloc and calloc wrapper in the Bluetooth stack `osi_malloc` and `osi_calloc`, see osi_malloc code below in file [osi/src/allocator.cc](https://android.googlesource.com/platform/system/bt/+/refs/heads/master/osi/src/allocator.cc#59)
```
void* osi_malloc(size_t size) {
  size_t real_size = allocation_tracker_resize_for_canary(size);
  void* ptr = malloc(real_size);
  CHECK(ptr);
  return allocation_tracker_notify_alloc(alloc_allocator_id, ptr, size);
}
```
osi_calloc code below in file [osi/src/allocator.cc](https://android.googlesource.com/platform/system/bt/+/refs/heads/master/osi/src/allocator.cc#66)
```
void* osi_calloc(size_t size) {
  size_t real_size = allocation_tracker_resize_for_canary(size);
  void* ptr = calloc(1, real_size);
  CHECK(ptr);
  return allocation_tracker_notify_alloc(alloc_allocator_id, ptr, size);
}
```

For instance, let's take `osi_malloc` for example. In osi_malloc, if requested size is the size mentioned before (between MAX_SIZE_T - 16 <= size <= MAX_SIZE_T), the osi_malloc will allocate way less memory than expected and that would lead to illegal memory access and SIGSEGV. 

To show the issue I am going to take an easy route and modify the JNI mentioned on Android Bluetooth [documentation](https://source.android.com/devices/bluetooth). I am just doing this to make my point, as JNI is not part of the Fluoride BT stack, I assume it's fair to use it to trigger issue in Fluoride stack because it's a standalone Bluetooth stack, which could be used in OS other than Android. We consider two attack models:
1. Attack from an app on the same host. The attacker app on the same host could register a SDP record with a very long name against the Fluoride BT stack, which could crash the BT service and causing Denial of Service.
2. Attack from another bluetooth device. The attacker (i.e. SDP client) can abuse the Service Discovery Protocol by sending a very long name against the vulnerable device (i.e. SDP server) and crash the BT service and cause Denial of Service.

The issue could be triggered in one way by doing this: in the Android source code, in the file `packages/apps/Bluetooth/jni/com_android_bluetooth_sdp.cpp` available [here](https://android.googlesource.com/platform/packages/apps/Bluetooth/+/refs/heads/master/jni/com_android_bluetooth_sdp.cpp#409), which is part of JNI not Fluoride BT stack, in the function `sdpCreateOppOpsRecordNative` - change the length to between `MAX_SIZE_T - 16` - `MAX_SIZE_T`. Making this change will trigger the issue in `osi_malloc` of Fluoride BT stack, which is used prolifically in the stack. For an instance to show the change in `com_android_bluetooth_sdp.cpp` to trigger the issue, see below:
```
static jint sdpCreateOppOpsRecordNative(JNIEnv* env, jobject obj,
                                        jstring name_str, jint scn,
                                        jint l2cap_psm, jint version,
                                        jbyteArray supported_formats_list) {
  ALOGD("%s", __func__);
  if (!sBluetoothSdpInterface) return -1;
  bluetooth_sdp_record record = {};  // Must be zero initialized
  record.ops.hdr.type = SDP_TYPE_OPP_SERVER;
  const char* service_name = NULL;
  if (name_str != NULL) {
    service_name = env->GetStringUTFChars(name_str, NULL);
    record.ops.hdr.service_name = (char*)service_name;
    record.ops.hdr.service_name_length = strlen(service_name);
    record.ops.hdr.service_name_length = 0xFFFFFFF2; <------------ this is the change ----------------
  } else {
    record.ops.hdr.service_name = NULL;
    record.ops.hdr.service_name_length = 0;
  }
  record.ops.hdr.rfcomm_channel_number = scn;
  record.ops.hdr.l2cap_psm = l2cap_psm;
  record.ops.hdr.profile_version = version;
  int formats_list_len = 0;
  jbyte* formats_list = env->GetByteArrayElements(supported_formats_list, NULL);
  if (formats_list != NULL) {
    formats_list_len = env->GetArrayLength(supported_formats_list);
    if (formats_list_len > SDP_OPP_SUPPORTED_FORMATS_MAX_LENGTH) {
      formats_list_len = SDP_OPP_SUPPORTED_FORMATS_MAX_LENGTH;
    }
    memcpy(record.ops.supported_formats_list, formats_list, formats_list_len);
  }
  record.ops.supported_formats_list_len = formats_list_len;
  int handle = -1;
  int ret = sBluetoothSdpInterface->create_sdp_record(&record, &handle); <---- call to BT stack
  if (ret != BT_STATUS_SUCCESS) {
    ALOGE("SDP Create record failed: %d", ret);
  } else {
    ALOGD("SDP Create record success - handle: %d", handle);
  }
  if (service_name) env->ReleaseStringUTFChars(name_str, service_name);
  if (formats_list)
    env->ReleaseByteArrayElements(supported_formats_list, formats_list, 0);
  return handle;
}
```
 
I am also providing the modified files that could be used to replace the original files to produce the issue and generate appropriate logs to show the problem. Provided modified files are from Fluoride BT stack as well, but these files are only modified to add logs and they don't change any implementation logic of the stack. I hope I make it clear. You can see the changes after copying the new files with command `repo diff` on `system/bt` in AOSP source code directory, you would only see log related changes.

As I mentioned before `com_android_bluetooth_sdp.cpp` is modified to trigger the issue . This change will trigger the issue as `sdpCreateOppOpsRecordNative` calls the `create_sdp_record` API of the Fluoride BT stack as `sBluetoothSdpInterface->create_sdp_record(&record, &handle);`. This takes control flow to function `create_sdp_record` in file [system/bt//btif/src/btif_sdp_server.cc](https://android.googlesource.com/platform/system/bt/+/refs/heads/master/btif/src/btif_sdp_server.cc#272) in BT stack. All the code mentioned below now onwards is part of the stack.

```
bt_status_t create_sdp_record(bluetooth_sdp_record* record,
                              int* record_handle) {
  int handle;
  handle = alloc_sdp_slot(record); <----------
  BTIF_TRACE_DEBUG("%s() handle = 0x%08x", __func__, handle);
  if (handle < 0) return BT_STATUS_FAIL;
  BTA_SdpCreateRecordByUser(INT_TO_PTR(handle));
  *record_handle = handle;
  return BT_STATUS_SUCCESS;
}
```

`create_sdp_record` calls [alloc_sdp_slot](https://android.googlesource.com/platform/system/bt/+/refs/heads/master/btif/src/btif_sdp_server.cc#192) present in same file to allocate space then copy the incoming SDP record.
```
static int alloc_sdp_slot(bluetooth_sdp_record* in_record) {
  int record_size = get_sdp_records_size(in_record, 1); <----------
  /* We are optimists here, and preallocate the record.
   * This is to reduce the time we hold the sdp_lock. */
  bluetooth_sdp_record* record = (bluetooth_sdp_record*)osi_malloc(record_size);<--- osi_malloc call in question
  copy_sdp_records(in_record, record, 1);
  {
    std::unique_lock<std::recursive_mutex> lock(sdp_lock);
    for (int i = 0; i < MAX_SDP_SLOTS; i++) {
      if (sdp_slots[i].state == SDP_RECORD_FREE) {
        sdp_slots[i].state = SDP_RECORD_ALLOCED;
        sdp_slots[i].record_data = record;
        return i;
      }
    }
  }
  APPL_TRACE_ERROR("%s() failed - no more free slots!", __func__);
  /* Rearly the optimist is too optimistic, and cleanup is needed...*/
  osi_free(record);
  return -1;
}
```

alloc_sdp_slot calls [get_sdp_records_size](https://android.googlesource.com/platform/system/bt/+/refs/heads/master/btif/src/btif_sdp_server.cc#123) to calculate the size of incoming to allocate proper space to make a copy of the record. `get_sdp_records_size` uses the service_name_length to calculate the size of buffer going to store the SDP record. If there is a huge service_name_length between `MAX_SIZE_T - 16` - `MAX_SIZE_T`, that will trigger the issue without my change in the `com_android_bluetooth_sdp.cpp`.


```
int get_sdp_records_size(bluetooth_sdp_record* in_record, int count) {
  bluetooth_sdp_record* record = in_record;
  int records_size = 0;
  int i;
  for (i = 0; i < count; i++) {
    record = &in_record[i];
    records_size += sizeof(bluetooth_sdp_record);
    records_size += record->hdr.service_name_length;
    if (record->hdr.service_name_length > 0) {
      records_size++; /* + '\0' termination of string */
    }
    records_size += record->hdr.user1_ptr_len;
    records_size += record->hdr.user2_ptr_len;
  }
  return records_size;
}
```

Another important thing to note is `record_size` is of type `signed int` and `osi_malloc` takes `size_t`. As per the upcasting rule in C which says: for signed to unsigned types, it sign-extends, then casts; this cannot always preserve the value, as a negative value cannot be represented with unsigned types. So, if record_size is more than 0x0FFFFFFF (more than max of signed int or -ve) - by the rule of upcasting it will be converted by padding `FF` on MSB (most significant bit). It's a bigger problem because if `osi_malloc` is called from a piece code inside the stack that uses a `signed short`, -ve value in the short variable would introduce the same issue, causing integer overflow and allocating lesser than intended memory.


To produce the issue follow below step:

1. Download the AOSP source code as described [here](https://source.android.com/setup/build/downloading)

2. Replace the attache files as mentioned below:
```
com_android_bluetooth_sdp.cpp -> packages/apps/Bluetooth/jni/com_android_bluetooth_sdp.cpp
btif_sdp_server.cc -> system/bt/btif/src/btif_sdp_server.cc
allocator.cc -> system/bt/osi/src/allocator.cc
```
3. go to source directory with `cd source`
4. run these commands to build the AOSP with the changes
```
source build/envsetup.sh
export ALLOW_NINJA_ENV=true
lunch sdk_phone_x86_64
m
```
5. Once build is finished, launch emulator to run the changes inside the emulator with command `emulator` from same terminal where commands mentioned in step 4 were executed. If you are using different terminal use the all commands in step 4 except the last one `m` on the new terminal, that would make the `emulator` command available.
6. Open shell inside the terminal with command `adb shell`
7. Run the command `svc bluetooth enable` to make sure Bluetooth is on
7. In the emulator shell fire command `logcat -f /data/log.out` and let it run for a minute then exit by `ctrl + c` key press
8. Exit from the emulator shell with `exit` command
9. Pull the log file out with `adb pull /data/log.out`
10. Open the file and search for `sdpCreateOppOpsRecordNative` and you can see `libc    : Fatal signal 11 (SIGSEGV), code 2 (SEGV_ACCERR), fault addr 0x7fef195d4000 in tid 1306 (droid.bluetooth), pid 1306 (droid.bluetooth)` few lines below.


