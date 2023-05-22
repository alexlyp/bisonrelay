import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';
import 'all_platforms.dart';
import 'package:golib_plugin/definitions.dart';
import 'package:golib_plugin/mock.dart';

T _cast<T>(x) => x is T ? x : throw "Not a $T";

mixin BaseMobilePlatform on ChanneledPlatform, NtfStreams {
  String get majorPlatform => "mobile";

  Future<void> hello() async {
    await channel.invokeMethod('hello');
  }

  Future<String> getURL(String url) async =>
      await channel.invokeMethod('getURL', <String, dynamic>{'url': url});

  Future<void> setTag(String tag) async =>
      await channel.invokeMethod('setTag', <String, dynamic>{'tag': tag});

  Future<String> nextTime() async => await channel.invokeMethod('nextTime');

  Future<void> writeStr(String s) async =>
      await channel.invokeMethod('writeStr', <String, dynamic>{'s': s});

  Stream<String> readStream() {
    var channel = EventChannel('readStream');
    var stream = channel.receiveBroadcastStream();
    return stream.map<String>((e) => _cast<String>(e));
  }

  void readAsyncResults() async {
    var channel = EventChannel('cmdResultLoop');
    var stream = channel.receiveBroadcastStream();
    await for (var e in stream) {
      //print("LLLLLLLLL got result loop $x");

      int id = e["id"] ?? 0;
      String err = e["error"] ?? "";
      String jsonPayload = e["payload"] ?? "";
      int cmdType = e["type"] ?? 0;
      bool isError = err != "";

      var c = calls[id];
        if (c == null) {
          if (id == 0 && cmdType >= notificationsStartID) {
            try {
              handleNotifications(cmdType, isError, jsonPayload);
            } catch (exception, trace) {
              // Probably a decode error. Keep handling stuff.
              var err =
                  "Unable to handle notification ${cmdType.toRadixString(16)}: $exception\n$trace";
              print(err);
              print(jsonPayload);
              (() async => throw exception)();
            }
          } else {
            print("Received reply for unknown call $id - $e");
          }

          continue;
        }
        calls.remove(id);

        dynamic payload;
        if (jsonPayload != "") {
          payload = jsonDecode(jsonPayload);
        }

        if (isError) {
          c.completeError(err);
        } else {
          c.complete(payload);
        }
    }
  }

    handleNotifications(int cmd, bool isError, String jsonPayload) {
    dynamic payload;
    if (jsonPayload != "") {
      payload = jsonDecode(jsonPayload);
    }
    //print("XXXXXXXX $payload");

    switch (cmd) {
      case NTInviteAccepted:
        isError
            ? ntfAcceptedInvites.addError(payload)
            : ntfAcceptedInvites.add(RemoteUser.fromJson(payload));
        break;

      case NTInviteErrored:
        throw Exception(payload);

      case NTPM:
        isError
            ? ntfChatEvents.addError(payload)
            : ntfChatEvents.add(PM.fromJson(payload));
        break;

      case NTLocalIDNeeded:
        ntfConfs.add(ConfNotification(cmd, null));
        break;

      case NTFConfServerCert:
        ntfConfs.add(ConfNotification(cmd, ServerCert.fromJson(payload)));
        break;

      case NTServerSessChanged:
        ntfServerSess.add(ServerSessionState.fromJson(payload));
        break;

      case NTNOP:
        // NOP.
        break;

      case NTInvitedToGC:
        var evnt = GCInvitation.fromJson(payload);
        ntfChatEvents.add(evnt);
        break;

      case NTUserAcceptedGCInvite:
        var evnt = InviteToGC.fromJson(payload);
        ntfChatEvents.add(GCUserEvent(
            evnt.uid, evnt.gc, "Accepted our invitation to join the GC"));
        break;

      case NTGCJoined:
        var gc = GCAddressBookEntry.fromJson(payload);
        ntfGCListUpdates.add(gc);
        break;

      case NTGCMessage:
        var gcm = GCMsg.fromJson(payload);
        ntfChatEvents.add(gcm);
        break;

      case NTKXCompleted:
        ntfAcceptedInvites.add(RemoteUser.fromJson(payload));
        break;

      case NTTipReceived:
        var args = PayTipArgs.fromJson(payload);
        var it = InflightTip(nextEID(), args.uid, args.amount);
        it.state = ITS_received;
        ntfChatEvents.add(it);
        break;

      case NTPostReceived:
        var pr = PostSummary.fromJson(payload);
        ntfPostsFeed.add(pr);
        ntfChatEvents.add(FeedPostEvent(pr.from, pr.id, pr.title));
        break;

      case NTPostStatusReceived:
        var psr = PostStatusReceived.fromJson(payload);
        ntfPostStatusFeed.add(psr);
        break;

      case NTFileDownloadCompleted:
        var rf = ReceivedFile.fromJson(payload);
        ntfDownloadCompleted.add(rf);
        ntfChatEvents.add(FileDownloadedEvent(rf.uid, rf.diskPath));
        break;

      case NTFileDownloadProgress:
        var fdp = FileDownloadProgress.fromJson(payload);
        ntfDownloadProgress.add(fdp);
        break;

      case NTLogLine:
        ntfLogLines.add(payload);
        break;

      case NTLNConfPayReqRecvChan:
        var est = LNReqChannelEstValue.fromJson(payload);
        ntfConfs.add(ConfNotification(NTLNConfPayReqRecvChan, est));
        break;

      case NTLNInitialChainSyncUpdt:
        isError
            ? ntfLNInitChainSync.addError(payload)
            : ntfLNInitChainSync
                .add(LNInitialChainSyncUpdate.fromJson(payload));
        break;

      case NTConfFileDownload:
        var data = ConfirmFileDownload.fromJson(payload);
        ntfConfs.add(ConfNotification(NTConfFileDownload, data));
        break;

      case NTLNDcrlndStopped:
        ntfConfs.add(ConfNotification(NTLNDcrlndStopped, payload));
        break;

      case NTClientStopped:
        ntfConfs.add(ConfNotification(NTClientStopped, payload));
        break;

      case NTUserPostsList:
        var event = UserPostList.fromJson(payload);
        ntfChatEvents.add(event);
        break;

      case NTUserContentList:
        var event = UserContentList.fromJson(payload);
        ntfChatEvents.add(event);
        break;

      case NTPostSubscriptionResult:
        var event = PostSubscriptionResult.fromJson(payload);
        ntfChatEvents.add(event);
        break;

      case NTInvoiceGenFailed:
        ntfConfs.add(ConfNotification(
            NTInvoiceGenFailed, InvoiceGenFailed.fromJson(payload)));
        break;

      case NTGCVersionWarn:
        var event = GCVersionWarn.fromJson(payload);
        ntfChatEvents.add(event);
        break;

      case NTGCAddedMembers:
        var event = GCAddedMembers.fromJson(payload);
        ntfChatEvents.add(event);
        break;

      case NTGCUpgradedVersion:
        var event = GCUpgradedVersion.fromJson(payload);
        ntfChatEvents.add(event);
        break;

      case NTGCMemberParted:
        var event = GCMemberParted.fromJson(payload);
        ntfChatEvents.add(event);
        break;

      case NTGCAdminsChanged:
        var event = GCAdminsChanged.fromJson(payload);
        ntfChatEvents.add(event);
        break;

      case NTKXCSuggested:
        var event = KXSuggested.fromJson(payload);
        ntfChatEvents.add(event);
        break;

      case NTTipUserProgress:
        var event = TipProgressEvent.fromJson(payload);
        ntfChatEvents.add(event);
        break;

      case NTOnboardStateChanged:
        isError
            ? ntfnOnboardStateChanged.addError(payload)
            : ntfnOnboardStateChanged.add(OnboardState.fromJson(payload));
        break;

      case NTResourceFetched:
        var event = FetchedResource.fromJson(payload);
        ntfFetchedResources.add(event);
        break;

      case NTSimpleStoreOrderPlaced:
        var event = SSPlacedOrder.fromJson(payload);
        ntfSimpleStoreOrders.add(event);
        break;

      default:
        print("Received unknown notification ${cmd.toRadixString(16)}");
    }
  }


  int id = 1; // id of the next command to send to the lib.

  // map of oustanding calls.
  final Map<int, Completer<dynamic>> calls = {};

  Future<dynamic> asyncCall(int cmd, dynamic payload) async {
    var jsonPayload = jsonEncode(payload);

    // Use a fixed clientHandle as we currently only support a single client per UI.
    const clientHandle = 0x12131400;
    var cid = id == -1 ? 1 : id++; // skips 0 as id.

    var c = Completer<dynamic>();
    calls[cid] = c;
    Map<String, dynamic> args = {
      'typ': cmd,
      'id': cid,
      'handle': clientHandle,
      'payload': jsonPayload,
    };
    channel.invokeMethod('asyncCall', args);
    return c.future;
  }
}
