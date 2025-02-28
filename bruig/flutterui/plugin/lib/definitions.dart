import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:developer' as developer;

import 'package:convert/convert.dart';
import 'package:flutter/cupertino.dart';
import 'package:golib_plugin/mock.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:blake_hash/blake_hash.dart';

part 'definitions.g.dart';

@JsonSerializable()
class InitClient {
  @JsonKey(name: 'dbroot')
  final String dbRoot;
  @JsonKey(name: "downloads_dir")
  final String downloadsDir;
  @JsonKey(name: 'server_addr')
  final String serverAddr;
  @JsonKey(name: 'ln_rpc_host')
  final String lnRPCHost;
  @JsonKey(name: 'ln_tls_cert_path')
  final String lnTLSCertPath;
  @JsonKey(name: 'ln_macaroon_path')
  final String lnMacaroonPath;
  @JsonKey(name: 'log_file')
  final String logFile;
  @JsonKey(name: "msgs_root")
  final String msgsRoot;
  @JsonKey(name: 'debug_level')
  final String debugLevel;
  @JsonKey(name: 'wants_log_ntfns')
  final bool wantsLogNtfns;

  InitClient(
      this.dbRoot,
      this.downloadsDir,
      this.serverAddr,
      this.lnRPCHost,
      this.lnTLSCertPath,
      this.lnMacaroonPath,
      this.logFile,
      this.msgsRoot,
      this.debugLevel,
      this.wantsLogNtfns);

  Map<String, dynamic> toJson() => _$InitClientToJson(this);
}

@JsonSerializable()
class IDInit {
  final String nick;
  final String name;
  IDInit(this.nick, this.name);
  factory IDInit.fromJson(Map<String, dynamic> json) => _$IDInitFromJson(json);

  Map<String, dynamic> toJson() => _$IDInitToJson(this);
}

@JsonSerializable()
class LocalInfo {
  final String id;
  final String nick;
  LocalInfo(this.id, this.nick);
  factory LocalInfo.fromJson(Map<String, dynamic> json) =>
      _$LocalInfoFromJson(json);
}

@JsonSerializable()
class ServerCert {
  @JsonKey(name: "inner_fingerprint")
  final String innerFingerprint;
  @JsonKey(name: "outer_fingerprint")
  final String outerFingerprint;
  const ServerCert(this.innerFingerprint, this.outerFingerprint);

  factory ServerCert.fromJson(Map<String, dynamic> json) =>
      _$ServerCertFromJson(json);
}

const connStateOffline = 0;
const connStateCheckingWallet = 1;
const connStateOnline = 2;

@JsonSerializable()
class ServerSessionState {
  final int state;
  @JsonKey(name: "check_wallet_err")
  final String? checkWalletErr;
  const ServerSessionState(this.state, this.checkWalletErr);

  factory ServerSessionState.fromJson(Map<String, dynamic> json) =>
      _$ServerSessionStateFromJson(json);
  factory ServerSessionState.empty() =>
      ServerSessionState(connStateOffline, null);
}

@JsonSerializable()
class ServerInfo {
  final String innerFingerprint;
  final String outerFingerprint;
  final String serverAddr;
  const ServerInfo(
      {required this.innerFingerprint,
      required this.outerFingerprint,
      required this.serverAddr});
  const ServerInfo.empty()
      : this(innerFingerprint: "", outerFingerprint: "", serverAddr: "");

  factory ServerInfo.fromJson(Map<String, dynamic> json) =>
      _$ServerInfoFromJson(json);
}

@JsonSerializable()
class RemoteUser {
  final String uid;
  final String name;
  final String nick;

  const RemoteUser(this.uid, this.name, this.nick);

  factory RemoteUser.fromJson(Map<String, dynamic> json) =>
      _$RemoteUserFromJson(json);
}

class Invitation {
  final RemoteUser user;
  final Uint8List inviteBlob;
  Invitation(this.user, this.inviteBlob);
}

class ChatEvent {
  final String sid; // source id (user id, gc id, etc)
  final String msg;
  const ChatEvent(this.sid, this.msg);
}

@JsonSerializable()
class PM extends ChatEvent {
  final bool mine;
  final int timestamp;

  const PM(sid, msg, this.mine, this.timestamp) : super(sid, msg);

  factory PM.fromJson(Map<String, dynamic> json) => _$PMFromJson(json);
  Map<String, dynamic> toJson() => _$PMToJson(this);
}

@JsonSerializable()
class InviteToGC {
  final String gc;
  final String uid;
  InviteToGC(this.gc, this.uid);

  factory InviteToGC.fromJson(Map<String, dynamic> json) =>
      _$InviteToGCFromJson(json);
  Map<String, dynamic> toJson() => _$InviteToGCToJson(this);
}

@JsonSerializable()
class RMGroupInvite {
  final String name;
  final List<String> Members;
  final int token;
  final String description;
  final int expires;
  RMGroupInvite(
      this.name, this.Members, this.token, this.description, this.expires);

  factory RMGroupInvite.fromJson(Map<String, dynamic> json) =>
      _$RMGroupInviteFromJson(json);
}

@JsonSerializable()
class GCAddressBookEntry {
  final String id;
  final String name;
  final List<String> members;
  GCAddressBookEntry(this.id, this.name, this.members);

  factory GCAddressBookEntry.fromJson(Map<String, dynamic> json) =>
      _$GCAddressBookEntryFromJson(json);
}

@JsonSerializable()
class GCInvitation extends ChatEvent {
  final RemoteUser inviter;
  final int iid;
  final String name;
  GCInvitation(this.inviter, this.iid, this.name) : super(inviter.uid, "");

  factory GCInvitation.fromJson(Map<String, dynamic> json) =>
      _$GCInvitationFromJson(json);
}

@JsonSerializable()
class GCMsg extends ChatEvent {
  @JsonKey(name: "sender_uid")
  final String senderUID;
  final int timestamp;
  const GCMsg(this.senderUID, sid, msg, this.timestamp) : super(sid, msg);

  factory GCMsg.fromJson(Map<String, dynamic> json) => _$GCMsgFromJson(json);
}

@JsonSerializable()
class GCMsgToSend {
  final String gc;
  final String msg;
  GCMsgToSend(this.gc, this.msg);
  Map<String, dynamic> toJson() => _$GCMsgToSendToJson(this);
}

class GCUserEvent extends ChatEvent {
  final String uid;
  const GCUserEvent(this.uid, gcid, msg) : super(gcid, msg);
}

@JsonSerializable()
class GCRemoveUserArgs {
  final String gc;
  final String uid;
  GCRemoveUserArgs(this.gc, this.uid);
  Map<String, dynamic> toJson() => _$GCRemoveUserArgsToJson(this);
}

class FeedPostEvent extends ChatEvent {
  final String postID;
  final String title;
  const FeedPostEvent(uid, this.postID, this.title) : super(uid, "");
}

class FileDownloadedEvent extends ChatEvent {
  final String diskPath;
  const FileDownloadedEvent(uid, this.diskPath) : super(uid, "");
}

@JsonSerializable()
class AddressBookEntry {
  final String id;
  final String nick;
  final String name;
  final bool ignored;
  AddressBookEntry(this.id, this.nick, {this.name: "", this.ignored: false});

  factory AddressBookEntry.fromJson(Map<String, dynamic> json) =>
      _$AddressBookEntryFromJson(json);
}

const int ITS_unknown = 0;
const int ITS_started = 1;
const int ITS_completed = 2;
const int ITS_errored = 3;
const int ITS_received = 4;

class InflightTip extends ChatEvent with ChangeNotifier {
  final double amount;
  final int eid;
  InflightTip(this.eid, uid, this.amount,
      [this._state = ITS_unknown, this._error])
      : super(uid, "");

  int _state;
  int get state => _state;
  void set state(int v) {
    _state = v;
    notifyListeners();
  }

  Exception? _error;
  Exception? get error => _error;
  void set error(Exception? e) {
    if (e == null) throw Exception("Cannot set error to null");
    _error = e;
    _state = ITS_errored;
    notifyListeners();
  }
}

const CFDIR_GLOBAL = "global";
const CFDIR_SHARED = "shared";

@JsonSerializable()
class ShareFileArgs {
  final String filename;
  final String uid;
  final int cost;
  final String description;

  ShareFileArgs(this.filename, this.uid, this.cost, this.description);

  Map<String, dynamic> toJson() => _$ShareFileArgsToJson(this);
}

@JsonSerializable()
class UnshareFileArgs {
  final String fid;
  @JsonKey(includeIfNull: false)
  final String? uid;
  UnshareFileArgs(this.fid, this.uid);
  Map<String, dynamic> toJson() => _$UnshareFileArgsToJson(this);
}

@JsonSerializable()
class GetRemoteFileArgs {
  final String uid;
  final String fid;
  GetRemoteFileArgs(this.uid, this.fid);
  Map<String, dynamic> toJson() => _$GetRemoteFileArgsToJson(this);
}

@JsonSerializable()
class FileManifest {
  final int index;
  final int size;
  final String hash;

  FileManifest(this.index, this.size, this.hash);
  factory FileManifest.fromJson(Map<String, dynamic> json) =>
      _$FileManifestFromJson(json);
}

@JsonSerializable()
class FileMetadata {
  final int version;
  final int cost;
  final int size;
  final String directory;
  final String filename;
  final String description;
  final String hash;
  final List<FileManifest> manifest;
  final String signature;
  final Map<String, dynamic>? attributes;

  FileMetadata(
      this.version,
      this.cost,
      this.size,
      this.directory,
      this.filename,
      this.description,
      this.hash,
      this.manifest,
      this.signature,
      this.attributes);

  factory FileMetadata.fromJson(Map<String, dynamic> json) =>
      _$FileMetadataFromJson(json);
}

@JsonSerializable()
class SharedFile {
  @JsonKey(name: "file_hash")
  final String fileHash;
  final String fid;
  final String filename;
  SharedFile(this.fileHash, this.fid, this.filename);
  factory SharedFile.fromJson(Map<String, dynamic> json) =>
      _$SharedFileFromJson(json);
}

@JsonSerializable()
class SharedFileAndShares {
  @JsonKey(name: "shared_file")
  final SharedFile sf;
  final int cost;
  final bool global;
  final List<String> shares;
  SharedFileAndShares(this.sf, this.cost, this.global, this.shares);
  factory SharedFileAndShares.fromJson(Map<String, dynamic> json) =>
      _$SharedFileAndSharesFromJson(json);
}

@JsonSerializable()
class ReceivedFile {
  @JsonKey(name: "file_id")
  final String fid;
  final String uid;
  @JsonKey(name: "disk_path")
  final String diskPath;
  final FileMetadata metadata;
  ReceivedFile(this.fid, this.uid, this.diskPath, this.metadata);
  factory ReceivedFile.fromJson(Map<String, dynamic> json) =>
      _$ReceivedFileFromJson(json);
}

@JsonSerializable()
class UserContentList extends ChatEvent {
  final String uid;
  final List<ReceivedFile> files;

  UserContentList(this.uid, this.files) : super(uid, "");
  factory UserContentList.fromJson(Map<String, dynamic> json) =>
      _$UserContentListFromJson(json);
}

@JsonSerializable()
class PayTipArgs {
  final String uid;
  final double amount;
  PayTipArgs(this.uid, this.amount);
  Map<String, dynamic> toJson() => _$PayTipArgsToJson(this);
  factory PayTipArgs.fromJson(Map<String, dynamic> json) =>
      _$PayTipArgsFromJson(json);
}

const RMPVersion = "version"; // Post version
const RMPIdentifier = "identifier"; // Post identifier
const RMPDescription = "description"; // Post description
const RMPMain = "main"; // Main post body
const RMPTitle = "title"; // Title of the post
const RMPAttachment = "attachment"; // Attached file to the post
const RMPStatusFrom = "statusfrom"; // Status/post update from (author)
const RMPSignature = "signature"; // Signature for the post/status
const RMPParent = "parent"; // Parent status/post
const RMPStatusID = "statusid"; // Status ID in status updates
const RMPNonce = "nonce"; // Random nonce to avoid equal hashes
const RMPFromNick = "from_nick"; // Nick of origin for post/status
const RMPTimestamp = "timestamp"; // Timestamp of the status update

const RMPSHeart = "heart"; // Heart a post
const RMPSComment = "comment"; // Comment on a post
const RMPSHeartYes = "1"; // +1 heart
const RMPSHeartNo = "0"; // -1 heart

@JsonSerializable()
class PostMetadata {
  final int version;
  final Map<String, String> attributes;
  PostMetadata(this.version, this.attributes);
  factory PostMetadata.fromJson(Map<String, dynamic> json) =>
      _$PostMetadataFromJson(json);
}

@JsonSerializable()
class PostMetadataStatus {
  final int version;
  final String from;
  final String link;
  final Map<String, String> attributes;
  PostMetadataStatus(this.version, this.from, this.link, this.attributes);
  factory PostMetadataStatus.fromJson(Map<String, dynamic> json) =>
      _$PostMetadataStatusFromJson(json);

  String hash() {
    var h = Blake256();

    var versionBytes = Uint8List(32);
    versionBytes.buffer.asByteData().setUint64(0, version, Endian.little);

    var enc = Utf8Encoder();
    var wattr = (String key) {
      var bytes = enc.convert(attributes[key] ?? "");
      h.update(bytes);
    };

    h.update(versionBytes);
    h.update(enc.convert(from));
    wattr(RMPIdentifier);
    wattr(RMPDescription);
    wattr(RMPMain);
    wattr(RMPTitle);
    wattr(RMPParent);
    wattr(RMPSHeart);
    wattr(RMPSComment);
    wattr(RMPNonce);

    return hex.encode(h.digest());
  }
}

@JsonSerializable()
class PostReceived {
  final String uid;
  @JsonKey(name: "post_meta")
  final PostMetadata postMeta;
  PostReceived(this.uid, this.postMeta);
  factory PostReceived.fromJson(Map<String, dynamic> json) =>
      _$PostReceivedFromJson(json);
}

class FeedPost {
  final String uid;
  final String id;
  final String content;
  final String file;
  final DateTime date;

  FeedPost(this.uid, this.id, this.content, this.file, this.date);
}

@JsonSerializable()
class PostSummary {
  final String id;
  final String from;
  @JsonKey(name: "author_id")
  final String authorID;
  @JsonKey(name: "author_nick")
  final String authorNick;
  final DateTime date;
  @JsonKey(name: "last_status_ts")
  final DateTime lastStatusTS;
  final String title;

  PostSummary(this.id, this.from, this.authorID, this.authorNick, this.date,
      this.lastStatusTS, this.title);
  factory PostSummary.fromJson(Map<String, dynamic> json) =>
      _$PostSummaryFromJson(json);
}

@JsonSerializable()
class ReadPostArgs {
  final String from;
  final String pid;
  ReadPostArgs(this.from, this.pid);
  factory ReadPostArgs.fromJson(Map<String, dynamic> json) =>
      _$ReadPostArgsFromJson(json);
  Map<String, dynamic> toJson() => _$ReadPostArgsToJson(this);
}

@JsonSerializable()
class CommentPostArgs {
  final String from;
  final String pid;
  final String comment;
  final String? parent;
  CommentPostArgs(this.from, this.pid, this.comment, this.parent);
  Map<String, dynamic> toJson() => _$CommentPostArgsToJson(this);
}

@JsonSerializable()
class PostStatusReceived {
  @JsonKey(name: "post_from")
  final String postFrom;
  final String pid;
  @JsonKey(name: "status_from")
  final String statusFrom;
  final PostMetadataStatus status;
  final bool mine;
  PostStatusReceived(
      this.postFrom, this.pid, this.statusFrom, this.status, this.mine);
  factory PostStatusReceived.fromJson(Map<String, dynamic> json) =>
      _$PostStatusReceivedFromJson(json);
}

@JsonSerializable()
class MediateIDArgs {
  final String mediator;
  final String target;
  MediateIDArgs(this.mediator, this.target);
  Map<String, dynamic> toJson() => _$MediateIDArgsToJson(this);
}

@JsonSerializable()
class PostActionArgs {
  final String from;
  final String pid;
  PostActionArgs(this.from, this.pid);
  Map<String, dynamic> toJson() => _$PostActionArgsToJson(this);
}

class ConfNotification {
  final int type;
  final dynamic payload;
  ConfNotification(this.type, this.payload);
}

@JsonSerializable()
class OutstandingFileDownload {
  final String uid;
  final String fid;
  @JsonKey(name: "completed_name")
  final String completedName;
  final FileMetadata? metadata;
  @JsonKey(defaultValue: {})
  final Map<int, String> invoices;
  @JsonKey(name: "chunkstates", defaultValue: {})
  final Map<int, String> chunkStates;
  OutstandingFileDownload(this.uid, this.fid, this.completedName, this.metadata,
      this.invoices, this.chunkStates);
  factory OutstandingFileDownload.fromJson(Map<String, dynamic> json) =>
      _$OutstandingFileDownloadFromJson(json);
}

@JsonSerializable()
class FileDownloadProgress {
  final String uid;
  final String fid;
  final FileMetadata metadata;
  @JsonKey(name: "nb_missing_chunks")
  final int nbMissingChunks;
  FileDownloadProgress(this.uid, this.fid, this.metadata, this.nbMissingChunks);
  factory FileDownloadProgress.fromJson(Map<String, dynamic> json) =>
      _$FileDownloadProgressFromJson(json);
}

@JsonSerializable()
class LNChain {
  final String chain;
  final String network;

  LNChain(this.chain, this.network);
  factory LNChain.fromJson(Map<String, dynamic> json) =>
      _$LNChainFromJson(json);
}

@JsonSerializable()
class LNInfo {
  @JsonKey(name: "identity_pubkey")
  final String identityPubkey;
  final String version;
  @JsonKey(name: "num_active_channels", defaultValue: 0)
  final int numActiveChannels;
  @JsonKey(name: "num_inactive_channels", defaultValue: 0)
  final int numInactiveChannels;
  @JsonKey(name: "num_pending_channels", defaultValue: 0)
  final int numPendingChannels;
  @JsonKey(name: "synced_to_chain", defaultValue: false)
  final bool syncedToChain;
  @JsonKey(name: "synced_to_graph", defaultValue: false)
  final bool syncedToGraph;
  @JsonKey(name: "block_height")
  final int blockHeight;
  @JsonKey(name: "block_hash")
  final String blockHash;
  final List<LNChain> chains;

  LNInfo(
      this.identityPubkey,
      this.version,
      this.numActiveChannels,
      this.numInactiveChannels,
      this.numPendingChannels,
      this.syncedToChain,
      this.syncedToGraph,
      this.blockHeight,
      this.blockHash,
      this.chains);
  factory LNInfo.fromJson(Map<String, dynamic> json) => _$LNInfoFromJson(json);
  factory LNInfo.empty() => LNInfo("", "", 0, 0, 0, false, false, 0, "", []);
}

@JsonSerializable()
class LNChannel {
  @JsonKey(defaultValue: false)
  final bool active;
  @JsonKey(name: "remote_pubkey")
  final String remotePubkey;
  @JsonKey(name: "channel_point")
  final String channelPoint;
  @JsonKey(name: "chan_id")
  final int chanID;
  final int capacity;
  @JsonKey(name: "local_balance", defaultValue: 0)
  final int localBalance;
  @JsonKey(name: "remote_balance", defaultValue: 0)
  final int remoteBalance;
  LNChannel(this.active, this.remotePubkey, this.channelPoint, this.chanID,
      this.capacity, this.localBalance, this.remoteBalance);
  factory LNChannel.fromJson(Map<String, dynamic> json) =>
      _$LNChannelFromJson(json);
}

@JsonSerializable()
class LNPendingChannel {
  @JsonKey(name: "remote_node_pub")
  final String remoteNodePub;
  @JsonKey(name: "channel_point")
  final String channelPoint;
  final int capacity;
  @JsonKey(name: "local_balance", defaultValue: 0)
  final int localBalance;
  @JsonKey(name: "remote_balance", defaultValue: 0)
  final int remoteBalance;
  @JsonKey(defaultValue: 0)
  final int initiator;

  LNPendingChannel(this.remoteNodePub, this.channelPoint, this.capacity,
      this.localBalance, this.remoteBalance, this.initiator);
  factory LNPendingChannel.fromJson(Map<String, dynamic> json) =>
      _$LNPendingChannelFromJson(json);
}

@JsonSerializable()
class LNPendingOpenChannel {
  final LNPendingChannel channel;
  @JsonKey(name: "confirmation_height", defaultValue: 0)
  final int confirmationHeight;
  @JsonKey(name: "commit_fee", defaultValue: 0)
  final int commitFee;
  @JsonKey(name: "confirmation_size", defaultValue: 0)
  final int commitSize;
  @JsonKey(name: "fee_per_kb", defaultValue: 0)
  final int feePerKb;

  LNPendingOpenChannel(this.confirmationHeight, this.commitFee, this.commitSize,
      this.feePerKb, this.channel);
  factory LNPendingOpenChannel.fromJson(Map<String, dynamic> json) =>
      _$LNPendingOpenChannelFromJson(json);
}

@JsonSerializable()
class LNWaitingCloseChannel {
  final LNPendingChannel channel;
  LNWaitingCloseChannel(this.channel);
  factory LNWaitingCloseChannel.fromJson(Map<String, dynamic> json) =>
      _$LNWaitingCloseChannelFromJson(json);
}

@JsonSerializable()
class LNPendingForceClosingChannel {
  final LNPendingChannel channel;
  @JsonKey(name: "closing_txid", defaultValue: "")
  final String closingTxid;
  @JsonKey(name: "maturityHeight", defaultValue: 0)
  final int maturityHeight;
  @JsonKey(name: "blocksTilMaturity", defaultValue: 0)
  final int blocksTilMaturity;
  @JsonKey(name: "recoveredBalance", defaultValue: 0)
  final int recoveredBalance;
  LNPendingForceClosingChannel(this.channel, this.closingTxid,
      this.maturityHeight, this.blocksTilMaturity, this.recoveredBalance);
  factory LNPendingForceClosingChannel.fromJson(Map<String, dynamic> json) =>
      _$LNPendingForceClosingChannelFromJson(json);
}

@JsonSerializable()
class LNPendingChannelsList {
  @JsonKey(name: "pending_open_channels", defaultValue: [])
  final List<LNPendingOpenChannel> pendingOpen;
  @JsonKey(name: "pending_force_closing_channels", defaultValue: [])
  final List<LNPendingForceClosingChannel> pendingForceClose;
  @JsonKey(name: "waiting_close_channels", defaultValue: [])
  final List<LNWaitingCloseChannel> waitingClose;
  LNPendingChannelsList(
      this.pendingOpen, this.pendingForceClose, this.waitingClose);
  factory LNPendingChannelsList.fromJson(Map<String, dynamic> json) =>
      _$LNPendingChannelsListFromJson(json);
  factory LNPendingChannelsList.empty() => LNPendingChannelsList([], [], []);
}

@JsonSerializable()
class LNGenInvoiceRequest {
  final String memo;
  final int value;
  LNGenInvoiceRequest(this.memo, this.value);
  Map<String, dynamic> toJson() => _$LNGenInvoiceRequestToJson(this);
  factory LNGenInvoiceRequest.fromJson(Map<String, dynamic> json) =>
      _$LNGenInvoiceRequestFromJson(json);
}

@JsonSerializable()
class LNGenInvoiceResponse {
  @JsonKey(name: "r_hash")
  final String rhash;
  @JsonKey(name: "payment_request")
  final String paymentRequest;
  LNGenInvoiceResponse(this.rhash, this.paymentRequest);
  factory LNGenInvoiceResponse.fromJson(Map<String, dynamic> json) =>
      _$LNGenInvoiceResponseFromJson(json);
}

@JsonSerializable()
class LNPayInvoiceResponse {
  @JsonKey(name: "payment_error", defaultValue: "")
  final String paymentError;
  @JsonKey(name: "payment_preimage", fromJson: base64ToHex)
  final String preimage;
  @JsonKey(name: "payment_hash", fromJson: base64ToHex)
  final String paymentHash;
  LNPayInvoiceResponse(this.paymentError, this.preimage, this.paymentHash);
  factory LNPayInvoiceResponse.fromJson(Map<String, dynamic> json) =>
      _$LNPayInvoiceResponseFromJson(json);
}

@JsonSerializable()
class LNQueryRouteRequest {
  @JsonKey(name: "pub_key")
  final String pubkey;
  @JsonKey(name: "amt")
  final int amount;
  LNQueryRouteRequest(this.pubkey, this.amount);
  Map<String, dynamic> toJson() => _$LNQueryRouteRequestToJson(this);
  factory LNQueryRouteRequest.fromJson(Map<String, dynamic> json) =>
      _$LNQueryRouteRequestFromJson(json);
}

@JsonSerializable()
class LNHop {
  @JsonKey(name: "chan_id", defaultValue: 0)
  final int chanId;
  @JsonKey(name: "chan_capacity", defaultValue: 0)
  final int chanCapacity;
  @JsonKey(name: "pub_key")
  final String pubkey;

  LNHop(this.chanId, this.chanCapacity, this.pubkey);
  factory LNHop.fromJson(Map<String, dynamic> json) => _$LNHopFromJson(json);
}

@JsonSerializable()
class LNRoute {
  @JsonKey(name: "total_time_lock")
  final int totalTimeLock;
  @JsonKey(name: "total_fees", defaultValue: 0)
  final int totalFees;
  @JsonKey(defaultValue: [])
  final List<LNHop> hops;

  LNRoute(this.totalTimeLock, this.totalFees, this.hops);
  factory LNRoute.fromJson(Map<String, dynamic> json) =>
      _$LNRouteFromJson(json);
}

@JsonSerializable()
class LNQueryRouteResponse {
  @JsonKey(defaultValue: [])
  final List<LNRoute> routes;
  @JsonKey(name: "success_prob", defaultValue: 0)
  final double successProb;
  LNQueryRouteResponse(this.routes, this.successProb);
  factory LNQueryRouteResponse.fromJson(Map<String, dynamic> json) =>
      _$LNQueryRouteResponseFromJson(json);
  factory LNQueryRouteResponse.empty() => LNQueryRouteResponse([], 0);
}

@JsonSerializable()
class LNGetNodeInfoRequest {
  @JsonKey(name: "pub_key")
  final String pubkey;
  @JsonKey(name: "include_channels", defaultValue: false)
  final bool includeChannels;

  LNGetNodeInfoRequest(this.pubkey, this.includeChannels);
  Map<String, dynamic> toJson() => _$LNGetNodeInfoRequestToJson(this);
}

@JsonSerializable()
class LNNode {
  @JsonKey(name: "pub_key")
  final String pubkey;
  @JsonKey(defaultValue: "")
  final String alias;
  @JsonKey(name: "last_update", defaultValue: 0)
  final int lastUpdate;

  LNNode(this.pubkey, this.alias, this.lastUpdate);
  factory LNNode.fromJson(Map<String, dynamic> json) => _$LNNodeFromJson(json);
}

@JsonSerializable()
class LNRoutingPolicy {
  @JsonKey(defaultValue: false)
  final bool disabled;
  @JsonKey(name: "last_update", defaultValue: 0)
  final int lastUpdate;

  LNRoutingPolicy(this.disabled, this.lastUpdate);
  factory LNRoutingPolicy.fromJson(Map<String, dynamic> json) =>
      _$LNRoutingPolicyFromJson(json);
}

@JsonSerializable()
class LNChannelEdge {
  @JsonKey(name: "channel_id", defaultValue: 0)
  final int channelID;
  @JsonKey(name: "chan_point")
  final String channelPoint;
  @JsonKey(name: "last_update", defaultValue: 0)
  final int lastUpdate;
  @JsonKey(name: "node1_pub")
  final String node1Pub;
  @JsonKey(name: "node2_pub")
  final String node2Pub;
  @JsonKey(name: "capacity", defaultValue: 0)
  final int capacity;
  @JsonKey(name: "node1_policy")
  final LNRoutingPolicy node1Policy;
  @JsonKey(name: "node2_policy")
  final LNRoutingPolicy node2Policy;

  LNChannelEdge(
      this.channelID,
      this.channelPoint,
      this.lastUpdate,
      this.node1Pub,
      this.node2Pub,
      this.capacity,
      this.node1Policy,
      this.node2Policy);

  factory LNChannelEdge.fromJson(Map<String, dynamic> json) =>
      _$LNChannelEdgeFromJson(json);
}

@JsonSerializable()
class LNGetNodeInfoResponse {
  final LNNode node;
  @JsonKey(name: "num_channels")
  final int numChannels;
  @JsonKey(name: "total_capacity", defaultValue: 0)
  final int totalCapacity;
  @JsonKey(defaultValue: [])
  final List<LNChannelEdge> channels;

  LNGetNodeInfoResponse(
      this.node, this.numChannels, this.totalCapacity, this.channels);
  factory LNGetNodeInfoResponse.fromJson(Map<String, dynamic> json) =>
      _$LNGetNodeInfoResponseFromJson(json);
  factory LNGetNodeInfoResponse.empty() =>
      LNGetNodeInfoResponse(LNNode("", "", 0), 0, 0, []);
}

@JsonSerializable()
class LNChannelBalance {
  @JsonKey(defaultValue: 0)
  final int balance;
  @JsonKey(name: "pending_open_balance", defaultValue: 0)
  final int pendingOpenBalance;
  @JsonKey(name: "max_inbound_amount", defaultValue: 0)
  final int maxInboundAmount;
  @JsonKey(name: "max_outbound_amount", defaultValue: 0)
  final int maxOutboundAmount;
  LNChannelBalance(this.balance, this.pendingOpenBalance, this.maxInboundAmount,
      this.maxOutboundAmount);
  factory LNChannelBalance.fromJson(Map<String, dynamic> json) =>
      _$LNChannelBalanceFromJson(json);
}

@JsonSerializable()
class LNWalletBalance {
  @JsonKey(name: "total_balance", defaultValue: 0)
  final int totalBalance;
  @JsonKey(name: "confirmed_balance", defaultValue: 0)
  final int confirmedBalance;
  @JsonKey(name: "unconfirmed_balance", defaultValue: 0)
  final int unconfirmedBalance;
  LNWalletBalance(
      this.totalBalance, this.confirmedBalance, this.unconfirmedBalance);
  factory LNWalletBalance.fromJson(Map<String, dynamic> json) =>
      _$LNWalletBalanceFromJson(json);
}

@JsonSerializable()
class LNBalances {
  final LNChannelBalance channel;
  final LNWalletBalance wallet;
  LNBalances(this.channel, this.wallet);
  factory LNBalances.fromJson(Map<String, dynamic> json) =>
      _$LNBalancesFromJson(json);
  factory LNBalances.empty() =>
      LNBalances(LNChannelBalance(0, 0, 0, 0), LNWalletBalance(0, 0, 0));
}

@JsonSerializable()
class LNDecodedInvoice {
  final String destination;
  @JsonKey(name: "payment_hash")
  final String paymentHash;
  @JsonKey(defaultValue: 0)
  @JsonKey(name: "num_atoms", defaultValue: 0)
  final int numAtoms;
  @JsonKey(name: "num_m_atoms", defaultValue: 0)
  final int numMAtoms;
  @JsonKey(defaultValue: 3600)
  final int expiry;
  @JsonKey(defaultValue: "")
  final String description;
  @JsonKey(defaultValue: 0)
  final int timestamp;

  double get amount =>
      numAtoms > 0 ? numAtoms.toDouble() / 1e8 : numMAtoms.toDouble() / 1e11;

  LNDecodedInvoice(this.destination, this.paymentHash, this.numAtoms,
      this.expiry, this.description, this.timestamp, this.numMAtoms);
  factory LNDecodedInvoice.fromJson(Map<String, dynamic> json) =>
      _$LNDecodedInvoiceFromJson(json);
}

@JsonSerializable()
class LNPayInvoiceRequest {
  @JsonKey(name: "payment_request")
  final String paymentRequest;
  final int amount;

  LNPayInvoiceRequest(this.paymentRequest, this.amount);
  Map<String, dynamic> toJson() => _$LNPayInvoiceRequestToJson(this);
  factory LNPayInvoiceRequest.fromJson(Map<String, dynamic> json) =>
      _$LNPayInvoiceRequestFromJson(json);
}

@JsonSerializable()
class LNPeer {
  @JsonKey(name: "pub_key")
  final String pubkey;
  final String address;
  @JsonKey(defaultValue: false)
  final bool inbound;
  LNPeer(this.pubkey, this.address, this.inbound);
  factory LNPeer.fromJson(Map<String, dynamic> json) => _$LNPeerFromJson(json);
}

String hexToBase64(String? s) => s != null ? base64Encode(hex.decode(s)) : "";
String base64ToHex(String s) => s != null ? hex.encode(base64Decode(s)) : "";

@JsonSerializable()
class LNOpenChannelRequest {
  @JsonKey(name: "node_pubkey", toJson: hexToBase64)
  final String nodePubkey;
  @JsonKey(name: "local_funding_amount")
  final int localFundingAmount;
  @JsonKey(name: "push_atoms")
  final int pushAtoms;
  LNOpenChannelRequest(
      this.nodePubkey, this.localFundingAmount, this.pushAtoms);
  Map<String, dynamic> toJson() => _$LNOpenChannelRequestToJson(this);
}

@JsonSerializable()
class LNChannelPoint_FundingTxidStr {
  @JsonKey(name: "fundingTxidStr", defaultValue: "")
  final String fundingTxidStr;

  LNChannelPoint_FundingTxidStr(this.fundingTxidStr);
  Map<String, dynamic> toJson() => _$LNChannelPoint_FundingTxidStrToJson(this);
}

@JsonSerializable()
class LNChannelPoint_FundingTxidBytes {
  @JsonKey(name: "fundingTxidBytes", defaultValue: "")
  final String fundingTxidBytes;

  LNChannelPoint_FundingTxidBytes(this.fundingTxidBytes);
  Map<String, dynamic> toJson() =>
      _$LNChannelPoint_FundingTxidBytesToJson(this);
}

@JsonSerializable()
class LNChannelPoint {
  @JsonKey(name: "txid")
  final dynamic txid;
  @JsonKey(name: "output_index", defaultValue: 0)
  final int outputIndex;

  LNChannelPoint(this.txid, this.outputIndex);
  Map<String, dynamic> toJson() => _$LNChannelPointToJson(this);
  factory LNChannelPoint.fromJson(Map<String, dynamic> json) =>
      _$LNChannelPointFromJson(json);

  factory LNChannelPoint.fromChanPointStr(String chanpoint) {
    var sub = chanpoint.split(":");
    if (sub.length != 2) {
      throw "Incorrect nb of chapoint parts (want 2, got ${sub.length}";
    }
    int outIdx = int.parse(sub[1]);
    return LNChannelPoint(sub[0], outIdx);
  }
}

@JsonSerializable()
class LNCloseChannelRequest {
  @JsonKey(name: "channel_point")
  final LNChannelPoint channelPoint;
  final bool force;
  LNCloseChannelRequest(this.channelPoint, this.force);
  Map<String, dynamic> toJson() => _$LNCloseChannelRequestToJson(this);
}

@JsonSerializable()
class LNTryExternalDcrlnd {
  @JsonKey(name: "rpc_host")
  final String rpcHost;
  @JsonKey(name: "tls_cert_path")
  final String tlsCertPath;
  @JsonKey(name: "macaroon_path")
  final String macaroonPath;

  LNTryExternalDcrlnd(this.rpcHost, this.tlsCertPath, this.macaroonPath);
  Map<String, dynamic> toJson() => _$LNTryExternalDcrlndToJson(this);
}

@JsonSerializable()
class LNInitDcrlnd {
  @JsonKey(name: "root_dir")
  final String rootDir;
  final String network;
  final String password;

  LNInitDcrlnd(this.rootDir, this.network, this.password);
  Map<String, dynamic> toJson() => _$LNInitDcrlndToJson(this);
}

@JsonSerializable()
class LNNewWalletSeed {
  final String seed;
  @JsonKey(name: "rpc_host")
  final String rpcHost;

  LNNewWalletSeed(this.seed, this.rpcHost);
  factory LNNewWalletSeed.fromJson(Map<String, dynamic> json) =>
      _$LNNewWalletSeedFromJson(json);
}

@JsonSerializable()
class LNInitialChainSyncUpdate {
  @JsonKey(name: "block_height", defaultValue: 0)
  final int blockHeight;
  @JsonKey(name: "block_hash", fromJson: base64ToHex)
  final String blockHash;
  @JsonKey(name: "block_timestamp", defaultValue: 0)
  final int blockTimestamp;
  @JsonKey(defaultValue: false)
  final bool synced;

  LNInitialChainSyncUpdate(
      this.blockHeight, this.blockHash, this.blockTimestamp, this.synced);
  factory LNInitialChainSyncUpdate.fromJson(Map<String, dynamic> json) =>
      _$LNInitialChainSyncUpdateFromJson(json);
}

@JsonSerializable()
class LNReqChannelArgs {
  final String server;
  final String key;
  @JsonKey(name: "chan_size")
  final int chanSize;
  final String certificates;

  LNReqChannelArgs(this.server, this.key, this.chanSize, this.certificates);
  Map<String, dynamic> toJson() => _$LNReqChannelArgsToJson(this);
}

@JsonSerializable()
class LNReqChannelEstValue {
  @JsonKey(defaultValue: 0)
  final int amount;

  LNReqChannelEstValue(this.amount);
  factory LNReqChannelEstValue.fromJson(Map<String, dynamic> json) =>
      _$LNReqChannelEstValueFromJson(json);
}

@JsonSerializable()
class ConfirmFileDownload {
  final String uid;
  final String fid;
  final FileMetadata metadata;

  ConfirmFileDownload(this.uid, this.fid, this.metadata);
  factory ConfirmFileDownload.fromJson(Map<String, dynamic> json) =>
      _$ConfirmFileDownloadFromJson(json);
}

@JsonSerializable()
class ConfirmFileDownloadReply {
  final String fid;
  final bool reply;

  ConfirmFileDownloadReply(this.fid, this.reply);
  Map<String, dynamic> toJson() => _$ConfirmFileDownloadReplyToJson(this);
  factory ConfirmFileDownloadReply.fromJson(Map<String, dynamic> json) =>
      _$ConfirmFileDownloadReplyFromJson(json);
}

@JsonSerializable()
class SendFileArgs {
  final String uid;
  final String filepath;

  SendFileArgs(this.uid, this.filepath);
  Map<String, dynamic> toJson() => _$SendFileArgsToJson(this);
}

@JsonSerializable()
class UserPayStats {
  @JsonKey(name: "total_sent")
  final int totalSent;
  @JsonKey(name: "total_received")
  final int totalReceived;

  UserPayStats(this.totalSent, this.totalReceived);
  factory UserPayStats.fromJson(Map<String, dynamic> json) =>
      _$UserPayStatsFromJson(json);
}

@JsonSerializable()
class PayStatsSummary {
  final String prefix;
  final int total;

  PayStatsSummary(this.prefix, this.total);
  factory PayStatsSummary.fromJson(Map<String, dynamic> json) =>
      _$PayStatsSummaryFromJson(json);
}

@JsonSerializable()
class PostListItem {
  final String id;
  final String title;

  PostListItem(this.id, this.title);
  factory PostListItem.fromJson(Map<String, dynamic> json) =>
      _$PostListItemFromJson(json);
}

@JsonSerializable()
class UserPostList extends ChatEvent {
  final String uid;
  final List<PostListItem> posts;

  UserPostList(this.uid, this.posts) : super(uid, "");
  factory UserPostList.fromJson(Map<String, dynamic> json) =>
      _$UserPostListFromJson(json);
}

@JsonSerializable()
class LocalRenameArgs {
  final String id;
  @JsonKey(name: "new_name")
  final String newName;
  @JsonKey(name: "is_gc", defaultValue: false)
  final bool isGC;

  LocalRenameArgs(this.id, this.newName, this.isGC);
  factory LocalRenameArgs.fromJson(Map<String, dynamic> json) =>
      _$LocalRenameArgsFromJson(json);
  Map<String, dynamic> toJson() => _$LocalRenameArgsToJson(this);
}

mixin NtfStreams {
  StreamController<RemoteUser> ntfAcceptedInvites =
      StreamController<RemoteUser>();
  Stream<RemoteUser> acceptedInvites() => ntfAcceptedInvites.stream;

  StreamController<ChatEvent> ntfChatEvents = StreamController<ChatEvent>();
  Stream<ChatEvent> chatEvents() => ntfChatEvents.stream;

  StreamController<ConfNotification> ntfConfs =
      StreamController<ConfNotification>();
  Stream<ConfNotification> confirmations() => ntfConfs.stream;

  StreamController<ServerSessionState> ntfServerSess =
      StreamController<ServerSessionState>();
  Stream<ServerSessionState> serverSessionChanged() => ntfServerSess.stream;

  StreamController<GCAddressBookEntry> ntfGCListUpdates =
      StreamController<GCAddressBookEntry>();
  Stream<GCAddressBookEntry> gcListUpdates() => ntfGCListUpdates.stream;

  StreamController<PostSummary> ntfPostsFeed = StreamController<PostSummary>();
  Stream<PostSummary> postsFeed() => ntfPostsFeed.stream;

  StreamController<PostStatusReceived> ntfPostStatusFeed =
      StreamController<PostStatusReceived>();
  Stream<PostStatusReceived> postStatusFeed() => ntfPostStatusFeed.stream;

  StreamController<ReceivedFile> ntfDownloadCompleted =
      StreamController<ReceivedFile>();
  Stream<ReceivedFile> downloadsCompleted() => ntfDownloadCompleted.stream;

  StreamController<String> ntfLogLines = StreamController<String>();
  Stream<String> logLines() => ntfLogLines.stream;

  StreamController<FileDownloadProgress> ntfDownloadProgress =
      StreamController<FileDownloadProgress>();
  Stream<FileDownloadProgress> downloadProgress() => ntfDownloadProgress.stream;

  StreamController<LNInitialChainSyncUpdate> ntfLNInitChainSync =
      StreamController<LNInitialChainSyncUpdate>();
  Stream<LNInitialChainSyncUpdate> lnInitChainSyncProgress() =>
      ntfLNInitChainSync.stream;
}

abstract class PluginPlatform {
  Future<String?> get platformVersion async {}
  String get majorPlatform => "unknown-major-plat";
  String get minorPlatform => "unknown-minor-plat";
  Future<void> setTag(String tag) async => throw "unimplemented";
  Future<void> hello() async => throw "unimplemented";
  Future<String> getURL(String url) async => throw "unimplemented";
  Future<String> nextTime() async => throw "unimplemented";
  Future<void> writeStr(String s) async => throw "unimplemented";
  Stream<String> readStream() async* {
    throw "unimplemented";
  }

  Stream<RemoteUser> acceptedInvites() => throw "unimplemented";
  Stream<ChatEvent> chatEvents() => throw "unimplemented";
  Stream<ConfNotification> confirmations() => throw "unimplemented";
  Stream<ServerSessionState> serverSessionChanged() => throw "unimplemented";
  Stream<GCInvitation> gcInvitations() => throw "unimplemented";
  Stream<GCAddressBookEntry> gcListUpdates() => throw "unimplemented";
  Stream<PostSummary> postsFeed() => throw "unimplemented";
  Stream<ReceivedFile> downloadsCompleted() => throw "unimplemented";
  Stream<PostStatusReceived> postStatusFeed() => throw "unimplemented";
  Stream<String> logLines() => throw "unimplemented";
  Stream<FileDownloadProgress> downloadProgress() => throw "unimplemented";
  Stream<LNInitialChainSyncUpdate> lnInitChainSyncProgress() =>
      throw "unimplemented";

  Future<bool> hasServer() async => throw "unimplemented";

  Future<dynamic> asyncCall(int cmd, dynamic payload) async =>
      throw "unimplemented";

  Future<String> asyncHello(String name) async {
    var r = await asyncCall(CTHello, name);
    return r as String;
  }

  Future<void> initClient(InitClient args) async {
    await asyncCall(CTInitClient, args);
  }

  Future<void> initID(IDInit args) async {
    await asyncCall(CTLocalID, args);
  }

  Future<LocalInfo> getLocalInfo() async {
    return LocalInfo.fromJson(await asyncCall(CTGetLocalInfo, null));
  }

  Future<List<AddressBookEntry>> addressBook() async {
    var payload = await asyncCall(CTAddressBook, "");
    var list = payload as List;
    var l = list.map((v) => AddressBookEntry.fromJson(v)).toList();
    return l;
  }

  Future<String> userNick(String uid) async {
    return await asyncCall(CTGetUserNick, uid);
  }

  Future<void> generateInvite(String filepath) async {
    var blobRaw = await asyncCall(CTInvite, "");
    var blobDecoded = base64Decode(blobRaw as String);
    var f = File(filepath);
    await f.writeAsBytes(blobDecoded);
  }

  Future<Invitation> decodeInvite(String filepath) async {
    var f = File(filepath);
    var blobRaw = await f.readAsBytes();
    var res = await asyncCall(CTDecodeInvite, blobRaw);
    return Invitation(RemoteUser.fromJson(res), blobRaw);
  }

  Future<RemoteUser> acceptInvite(Invitation invite) async {
    var res = await asyncCall(CTAcceptInvite, invite.inviteBlob);
    return RemoteUser.fromJson(res);
  }

  Future<void> goOnline() async {
    await asyncCall(CTGoOnline, "");
  }

  Future<void> remainOffline() async {
    await asyncCall(CTRemainOffline, "");
  }

  Future<void> skipWalletCheck() async {
    await asyncCall(CTSkipWalletCheck, "");
  }

  Future<void> replyConfServerCert(bool accept) async {
    if (accept) {
      await asyncCall(CTAcceptServerCert, null);
    } else {
      await asyncCall(CTAcceptServerCert, null);
    }
  }

  Future<void> pm(PM msg) async => asyncCall(CTPM, msg);

  Future<void> createGC(String name) => asyncCall(CTNewGroupChat, name);

  Future<void> inviteToGC(InviteToGC inv) {
    return asyncCall(CTInviteToGroupChat, inv);
  }

  Future<void> acceptGCInvite(int iid) => asyncCall(CTAcceptGCInvite, iid);

  Future<GCAddressBookEntry> getGC(String name) async {
    var res = await asyncCall(CTGetGC, name);
    return GCAddressBookEntry.fromJson(res);
  }

  Future<void> sendToGC(String gc, String msg) =>
      asyncCall(CTGCMsg, GCMsgToSend(gc, msg));

  Future<List<GCAddressBookEntry>> listGCs() async {
    var res = await asyncCall(CTListGCs, null);
    return (res as List)
        .map<GCAddressBookEntry>((v) => GCAddressBookEntry.fromJson(v))
        .toList();
  }

  Future<void> removeGcUser(String gc, String uid) async {
    await asyncCall(CTGCRemoveUser, GCRemoveUserArgs(gc, uid));
  }

  Future<void> shareFile(
      String filename, String? uid, double cost, String descr) async {
    var args = ShareFileArgs(filename, uid ?? "", (cost * 1e8).round(), descr);
    await asyncCall(CTShareFile, args);
  }

  Future<void> unshareFile(String fid, String? uid) async {
    var args = UnshareFileArgs(fid, uid);
    await asyncCall(CTUnshareFile, args);
  }

  Future<List<SharedFileAndShares>> listSharedFiles() async {
    var res = await asyncCall(CTListSharedFiles, "");
    if (res == null) {
      return List<SharedFileAndShares>.empty();
    }
    return (res as List)
        .map<SharedFileAndShares>((v) => SharedFileAndShares.fromJson(v))
        .toList();
  }

  Future<void> listUserContent(String uid) async =>
      await asyncCall(CTListUserContent, uid);

  Future<void> getUserContent(String uid, String fid) async {
    var args = GetRemoteFileArgs(uid, fid);
    await asyncCall(CTGetUserContent, args);
  }

  InflightTip payTip(String uid, double amount) {
    var tip = InflightTip(nextEID(), uid, amount);
    tip.state = ITS_started;
    (() async {
      try {
        var args = PayTipArgs(uid, amount);
        await asyncCall(CTPayTip, args);
        tip.state = ITS_completed;
      } catch (error) {
        tip.error = Exception(error);
      }
    })();
    return tip;
  }

  Future<void> subscribeToPosts(String uid) async {
    await asyncCall(CTSubscribeToPosts, uid);
  }

  Future<void> requestKXReset(String uid) async {
    await asyncCall(CTKXReset, uid);
  }

  Future<List<PostSummary>> listPosts() async {
    var res = await asyncCall(CTListPosts, null);
    if (res == null) {
      return [];
    }
    return (res as List)
        .map<PostSummary>((v) => PostSummary.fromJson(v))
        .toList();
  }

  Future<PostMetadata> readPost(String from, String pid) async {
    var res = await asyncCall(CTReadPost, ReadPostArgs(from, pid));
    return PostMetadata.fromJson(res);
  }

  Future<List<PostMetadataStatus>> listPostStatus(
      String from, String pid) async {
    var res = await asyncCall(CTReadPostUpdates, ReadPostArgs(from, pid));
    if (res == null) {
      return List.empty();
    }
    return (res as List)
        .map<PostMetadataStatus>((v) => PostMetadataStatus.fromJson(v))
        .toList();
  }

  Future<void> commentPost(
      String from, String pid, String comment, String? parent) async {
    await asyncCall(CTCommentPost, CommentPostArgs(from, pid, comment, parent));
  }

  Future<void> requestMediateID(String mediator, String target) async {
    var req = MediateIDArgs(mediator, target);
    await asyncCall(CTRequestMediateID, req);
  }

  Future<void> kxSearchPostAuthor(String from, String pid) async {
    await asyncCall(CTKXSearchPostAuthor, PostActionArgs(from, pid));
  }

  Future<void> relayPostToAll(String from, String pid) async {
    await asyncCall(CTRelayPostToAll, PostActionArgs(from, pid));
  }

  Future<PostSummary> createPost(String content) async {
    return PostSummary.fromJson(await asyncCall(CTCreatePost, content));
  }

  Future<Map<String, dynamic>> getGCBlockList(String gcID) async {
    var res = await asyncCall(CTGCGetBlockList, gcID);
    if (res == null) {
      return {};
    }
    return res;
  }

  Future<void> addToGCBlockList(String gcID, String uid) async {
    await asyncCall(CTGCAddToBlockList, GCRemoveUserArgs(gcID, uid));
  }

  Future<void> removeFromGCBlockList(String gcID, String uid) async {
    await asyncCall(CTGCRemoveFromBlockList, GCRemoveUserArgs(gcID, uid));
  }

  Future<void> partFromGC(String gcID) async {
    return asyncCall(CTGCPart, gcID);
  }

  Future<void> killGC(String gcID) async {
    return asyncCall(CTGCKill, gcID);
  }

  Future<void> blockUser(String uid) async => await asyncCall(CTBlockUser, uid);
  Future<void> ignoreUser(String uid) async =>
      await asyncCall(CTIgnoreUser, uid);
  Future<void> unignoreUser(String uid) async =>
      await asyncCall(CTUnignoreUser, uid);
  Future<bool> isIgnored(String uid) async => await asyncCall(CTIsIgnored, uid);
  Future<List<String>> listSubscribers() async {
    var res = await asyncCall(CTListSubscribers, null);
    if (res == null) {
      return [];
    }
    return List.castFrom(res);
  }

  Future<List<String>> listSubscriptions() async {
    var res = await asyncCall(CTListSubscriptions, null);
    if (res == null) {
      return [];
    }
    return List.castFrom(res);
  }

  Future<List<OutstandingFileDownload>> listDownloads() async {
    var res = await asyncCall(CTListDownloads, null);
    if (res == null) {
      return [];
    }
    return (res as List)
        .map<OutstandingFileDownload>(
            (v) => OutstandingFileDownload.fromJson(v))
        .toList();
  }

  Future<LNInfo> lnGetInfo() async {
    var res = await asyncCall(CTLNGetInfo, null);
    return LNInfo.fromJson(res);
  }

  Future<List<LNChannel>> lnListChannels() async {
    var res = await asyncCall(CTLNListChannels, null);
    if (res == null || res["channels"] == null) {
      return List.empty();
    }
    return (res["channels"] as List)
        .map<LNChannel>((v) => LNChannel.fromJson(v))
        .toList();
  }

  Future<LNPendingChannelsList> lnListPendingChannels() async {
    var res = await asyncCall(CTLNListPendingChannels, null);
    if (res == null) {
      return LNPendingChannelsList.empty();
    }
    return LNPendingChannelsList.fromJson(res);
  }

  Future<LNGenInvoiceResponse> lnGenInvoice(
      double dcrAmount, String memo) async {
    var req = LNGenInvoiceRequest(memo, (dcrAmount * 1e8).truncate());
    var res = await asyncCall(CTLNGenInvoice, req);
    return LNGenInvoiceResponse.fromJson(res);
  }

  Future<LNPayInvoiceResponse> lnPayInvoice(
      String invoice, double dcrAmount) async {
    var amt = (dcrAmount * 1e8).truncate();
    var res =
        await asyncCall(CTLNPayInvoice, LNPayInvoiceRequest(invoice, amt));
    return LNPayInvoiceResponse.fromJson(res);
  }

  Future<String> lnGetServerNode() async {
    var res = await asyncCall(CTLNGetServerNode, null);
    return res;
  }

  Future<LNQueryRouteResponse> lnQueryRoute(
      double dcrAmount, String target) async {
    var req = LNQueryRouteRequest(target, (dcrAmount * 1e8).truncate());
    var res = await asyncCall(CTLNQueryRoute, req);
    return LNQueryRouteResponse.fromJson(res);
  }

  Future<LNGetNodeInfoResponse> lnGetNodeInfo(String target) async {
    var req = LNGetNodeInfoRequest(target, true);
    var res = await asyncCall(CTLNGetNodeInfo, req);
    developer.log(res);
    return LNGetNodeInfoResponse.fromJson(res);
  }

  Future<LNBalances> lnGetBalances() async {
    var res = await asyncCall(CTLNGetBalances, null);
    return LNBalances.fromJson(res);
  }

  Future<LNDecodedInvoice> lnDecodeInvoice(String invoice) async {
    var res = await asyncCall(CTLNDecodeInvoice, invoice);
    return LNDecodedInvoice.fromJson(res);
  }

  Future<List<LNPeer>> lnListPeers() async {
    var res = await asyncCall(CTLNListPeers, null);
    if (res == null || res["peers"] == null) {
      return List.empty();
    }
    return (res["peers"] as List)
        .map<LNPeer>((v) => LNPeer.fromJson(v))
        .toList();
  }

  Future<void> lnConnectToPeer(String addr) async =>
      await asyncCall(CTLNConnectToPeer, addr);
  Future<void> lnDisconnectFromPeer(String pubkey) async =>
      await asyncCall(CTLNDisconnectFromPeer, pubkey);

  Future<void> lnOpenChannel(
      String pubkey, double amount, double pushAmount) async {
    var req = LNOpenChannelRequest(
        pubkey, (amount * 1e8).truncate(), (pushAmount * 1e8).truncate());
    return await asyncCall(CTLNOpenChannel, req);
  }

  Future<void> lnCloseChannel(String channelPoint, bool force) async {
    var req = LNCloseChannelRequest(
        LNChannelPoint.fromChanPointStr(channelPoint), force);
    await asyncCall(CTLNCloseChannel, req);
  }

  Future<LNInfo> lnTryExternalDcrlnd(
      String rpcHost, String tlsCertPath, String macaroonPath) async {
    var req = LNTryExternalDcrlnd(rpcHost, tlsCertPath, macaroonPath);
    var res = await asyncCall(CTLNTryExternalDcrlnd, req);
    return LNInfo.fromJson(res);
  }

  Future<LNNewWalletSeed> lnInitDcrlnd(
      String rootPath, String network, String password) async {
    var req = LNInitDcrlnd(rootPath, network, password);
    var res = await asyncCall(CTLNInitDcrlnd, req);
    return LNNewWalletSeed.fromJson(res);
  }

  Future<String> lnRunDcrlnd(
      String rootPath, String network, String password) async {
    var req = LNInitDcrlnd(rootPath, network, password);
    var res = await asyncCall(CTLNRunDcrlnd, req);
    return res;
  }

  Future<String> lnGetDepositAddr() async =>
      await asyncCall(CTLNGetDepositAddr, null);

  Future<void> lnRequestRecvCapacity(String server, String key, double chanSize,
          String certificates) async =>
      await asyncCall(
          CTLNRequestRecvCapacity,
          LNReqChannelArgs(
              server, key, (chanSize * 1e8).toInt(), certificates));

  Future<void> lnConfirmPayReqRecvChan(bool value) async =>
      await asyncCall(CTLNConfirmPayReqRecvChan, value);

  void captureDcrlndLog() => asyncCall(CTCaptureDcrlndLog, null);

  Future<void> confirmFileDownload(String fid, bool confirm) async =>
      await asyncCall(
          CTConfirmFileDownload, ConfirmFileDownloadReply(fid, confirm));

  Future<void> sendFile(String uid, String filepath) async =>
      await asyncCall(CTSendFile, SendFileArgs(uid, filepath));

  Future<int> estimatePostSize(String content) async =>
      await asyncCall(CTEstimatePostSize, content);

  Future<void> stopClient() async => await asyncCall(CTStopClient, null);

  Future<void> lnStopDcrlnd() async => await asyncCall(CTLNStopDcrlnd, null);

  Future<Map<String, UserPayStats>> listPaymentStats() async {
    var res = await asyncCall(CTListPayStats, null);
    if (res == null) {
      return {};
    }
    return (res as Map<String, dynamic>).map<String, UserPayStats>(
        (k, v) => MapEntry(k, UserPayStats.fromJson(v)));
  }

  Future<List<PayStatsSummary>> summarizeUserPayStats(String uid) async {
    var res = await asyncCall(CTSummUserPayStats, uid);
    if (res == null) {
      return List.empty();
    }
    return (res as List)
        .map<PayStatsSummary>((v) => PayStatsSummary.fromJson(v))
        .toList();
  }

  Future<void> clearPayStats(String? uid) async =>
      await asyncCall(CTClearPayStats, uid);

  Future<void> listUserPosts(String uid) async =>
      await asyncCall(CTListUserPosts, uid);
  Future<void> getUserPost(String uid, String pid) async =>
      await asyncCall(CTGetUserPost, ReadPostArgs(uid, pid));

  Future<void> localRename(String id, String newName, bool isGC) async =>
      await asyncCall(CTLocalRename, LocalRenameArgs(id, newName, isGC));

  Future<void> createLockFile(String rootDir) async =>
      await asyncCall(CTCreateLockFile, rootDir);
  Future<void> closeLockFile(String rootDir) async =>
      await asyncCall(CTCloseLockFile, rootDir);
}

const int CTUnknown = 0x00;
const int CTHello = 0x01;
const int CTInitClient = 0x02;
const int CTInvite = 0x03;
const int CTDecodeInvite = 0x04;
const int CTAcceptInvite = 0x05;
const int CTPM = 0x06;
const int CTAddressBook = 0x07;
const int CTLocalID = 0x08;
const int CTAcceptServerCert = 0x09;
const int CTRejectServerCert = 0x0a;
const int CTNewGroupChat = 0x0b;
const int CTInviteToGroupChat = 0x0c;
const int CTAcceptGCInvite = 0x0d;
const int CTGetGC = 0x0e;
const int CTGCMsg = 0x0f;
const int CTListGCs = 0x10;
const int CTShareFile = 0x11;
const int CTUnshareFile = 0x12;
const int CTListSharedFiles = 0x13;
const int CTListUserContent = 0x14;
const int CTGetUserContent = 0x15;
const int CTPayTip = 0x16;
const int CTSubscribeToPosts = 0x17;
const int CTUnsubscribeToPosts = 0x18;
const int CTGCRemoveUser = 0x19;
const int CTKXReset = 0x20;
const int CTListPosts = 0x21;
const int CTReadPost = 0x22;
const int CTReadPostUpdates = 0x23;
const int CTGetUserNick = 0x24;
const int CTCommentPost = 0x25;
const int CTGetLocalInfo = 0x26;
const int CTRequestMediateID = 0x27;
const int CTKXSearchPostAuthor = 0x28;
const int CTRelayPostToAll = 0x29;
const int CTCreatePost = 0x30;
const int CTGCGetBlockList = 0x31;
const int CTGCAddToBlockList = 0x32;
const int CTGCRemoveFromBlockList = 0x33;
const int CTGCPart = 0x34;
const int CTGCKill = 0x35;
const int CTBlockUser = 0x36;
const int CTIgnoreUser = 0x37;
const int CTUnignoreUser = 0x38;
const int CTIsIgnored = 0x39;
const int CTListSubscribers = 0x3a;
const int CTListSubscriptions = 0x3b;
const int CTListDownloads = 0x3c;
const int CTLNGetInfo = 0x3d;
const int CTLNListChannels = 0x3e;
const int CTLNListPendingChannels = 0x3f;
const int CTLNGenInvoice = 0x40;
const int CTLNPayInvoice = 0x41;
const int CTLNGetServerNode = 0x42;
const int CTLNQueryRoute = 0x43;
const int CTLNGetBalances = 0x44;
const int CTLNDecodeInvoice = 0x45;
const int CTLNConnectToPeer = 0x47;
const int CTLNListPeers = 0x46;
const int CTLNDisconnectFromPeer = 0x48;
const int CTLNOpenChannel = 0x49;
const int CTLNCloseChannel = 0x4a;
const int CTLNTryExternalDcrlnd = 0x4b;
const int CTLNInitDcrlnd = 0x4c;
const int CTLNRunDcrlnd = 0x4d;
const int CTCaptureDcrlndLog = 0x4e;
const int CTLNGetDepositAddr = 0x4f;
const int CTLNRequestRecvCapacity = 0x50;
const int CTLNConfirmPayReqRecvChan = 0x51;
const int CTConfirmFileDownload = 0x52;
const int CTSendFile = 0x53;
const int CTEstimatePostSize = 0x54;
const int CTLNStopDcrlnd = 0x55;
const int CTStopClient = 0x56;
const int CTListPayStats = 0x57;
const int CTSummUserPayStats = 0x58;
const int CTClearPayStats = 0x59;
const int CTListUserPosts = 0x5a;
const int CTGetUserPost = 0x5b;
const int CTLocalRename = 0x5c;
const int CTGoOnline = 0x5d;
const int CTRemainOffline = 0x5e;
const int CTLNGetNodeInfo = 0x5f;
const int CTCreateLockFile = 0x60;
const int CTCloseLockFile = 0x61;
const int CTSkipWalletCheck = 0x62;

const int notificationsStartID = 0x1000;

const int NTInviteReceived = 0x1001;
const int NTInviteAccepted = 0x1002;
const int NTInviteErrored = 0x1003;
const int NTPM = 0x1004;
const int NTLocalIDNeeded = 0x1005;
const int NTFConfServerCert = 0x1006;
const int NTServerSessChanged = 0x1007;
const int NTNOP = 0x1008;
const int NTInvitedToGC = 0x1009;
const int NTUserAcceptedGCInvite = 0x100a;
const int NTGCListUpdated = 0x100b;
const int NTGCMessage = 0x100c;
const int NTKXCompleted = 0x100d;
const int NTTipReceived = 0x100e;
const int NTPostReceived = 0x100f;
const int NTFileDownloadConfirm = 0x1010;
const int NTFileDownloadCompleted = 0x1011;
const int NTFileDownloadProgress = 0x1012;
const int NTPostStatusReceived = 0x1013;
const int NTLogLine = 0x1014;
const int NTLNInitialChainSyncUpdt = 0x1015;
const int NTLNConfPayReqRecvChan = 0x1016;
const int NTConfFileDownload = 0x1017;
const int NTLNDcrlndStopped = 0x1018;
const int NTClientStopped = 0x1019;
const int NTUserPostsList = 0x101a;
const int NTUserContentList = 0x101b;
