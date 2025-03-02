// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'definitions.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

InitClient _$InitClientFromJson(Map<String, dynamic> json) => InitClient(
      json['dbroot'] as String,
      json['downloads_dir'] as String,
      json['server_addr'] as String,
      json['ln_rpc_host'] as String,
      json['ln_tls_cert_path'] as String,
      json['ln_macaroon_path'] as String,
      json['log_file'] as String,
      json['msgs_root'] as String,
      json['debug_level'] as String,
      json['wants_log_ntfns'] as bool,
    );

Map<String, dynamic> _$InitClientToJson(InitClient instance) =>
    <String, dynamic>{
      'dbroot': instance.dbRoot,
      'downloads_dir': instance.downloadsDir,
      'server_addr': instance.serverAddr,
      'ln_rpc_host': instance.lnRPCHost,
      'ln_tls_cert_path': instance.lnTLSCertPath,
      'ln_macaroon_path': instance.lnMacaroonPath,
      'log_file': instance.logFile,
      'msgs_root': instance.msgsRoot,
      'debug_level': instance.debugLevel,
      'wants_log_ntfns': instance.wantsLogNtfns,
    };

IDInit _$IDInitFromJson(Map<String, dynamic> json) => IDInit(
      json['nick'] as String,
      json['name'] as String,
    );

Map<String, dynamic> _$IDInitToJson(IDInit instance) => <String, dynamic>{
      'nick': instance.nick,
      'name': instance.name,
    };

LocalInfo _$LocalInfoFromJson(Map<String, dynamic> json) => LocalInfo(
      json['id'] as String,
      json['nick'] as String,
    );

Map<String, dynamic> _$LocalInfoToJson(LocalInfo instance) => <String, dynamic>{
      'id': instance.id,
      'nick': instance.nick,
    };

ServerCert _$ServerCertFromJson(Map<String, dynamic> json) => ServerCert(
      json['inner_fingerprint'] as String,
      json['outer_fingerprint'] as String,
    );

Map<String, dynamic> _$ServerCertToJson(ServerCert instance) =>
    <String, dynamic>{
      'inner_fingerprint': instance.innerFingerprint,
      'outer_fingerprint': instance.outerFingerprint,
    };

ServerSessionState _$ServerSessionStateFromJson(Map<String, dynamic> json) =>
    ServerSessionState(
      json['state'] as int,
      json['check_wallet_err'] as String?,
    );

Map<String, dynamic> _$ServerSessionStateToJson(ServerSessionState instance) =>
    <String, dynamic>{
      'state': instance.state,
      'check_wallet_err': instance.checkWalletErr,
    };

ServerInfo _$ServerInfoFromJson(Map<String, dynamic> json) => ServerInfo(
      innerFingerprint: json['innerFingerprint'] as String,
      outerFingerprint: json['outerFingerprint'] as String,
      serverAddr: json['serverAddr'] as String,
    );

Map<String, dynamic> _$ServerInfoToJson(ServerInfo instance) =>
    <String, dynamic>{
      'innerFingerprint': instance.innerFingerprint,
      'outerFingerprint': instance.outerFingerprint,
      'serverAddr': instance.serverAddr,
    };

RemoteUser _$RemoteUserFromJson(Map<String, dynamic> json) => RemoteUser(
      json['uid'] as String,
      json['name'] as String,
      json['nick'] as String,
    );

Map<String, dynamic> _$RemoteUserToJson(RemoteUser instance) =>
    <String, dynamic>{
      'uid': instance.uid,
      'name': instance.name,
      'nick': instance.nick,
    };

PM _$PMFromJson(Map<String, dynamic> json) => PM(
      json['sid'],
      json['msg'],
      json['mine'] as bool,
      json['timestamp'] as int,
    );

Map<String, dynamic> _$PMToJson(PM instance) => <String, dynamic>{
      'sid': instance.sid,
      'msg': instance.msg,
      'mine': instance.mine,
      'timestamp': instance.timestamp,
    };

InviteToGC _$InviteToGCFromJson(Map<String, dynamic> json) => InviteToGC(
      json['gc'] as String,
      json['uid'] as String,
    );

Map<String, dynamic> _$InviteToGCToJson(InviteToGC instance) =>
    <String, dynamic>{
      'gc': instance.gc,
      'uid': instance.uid,
    };

RMGroupInvite _$RMGroupInviteFromJson(Map<String, dynamic> json) =>
    RMGroupInvite(
      json['name'] as String,
      (json['Members'] as List<dynamic>).map((e) => e as String).toList(),
      json['token'] as int,
      json['description'] as String,
      json['expires'] as int,
    );

Map<String, dynamic> _$RMGroupInviteToJson(RMGroupInvite instance) =>
    <String, dynamic>{
      'name': instance.name,
      'Members': instance.Members,
      'token': instance.token,
      'description': instance.description,
      'expires': instance.expires,
    };

GCAddressBookEntry _$GCAddressBookEntryFromJson(Map<String, dynamic> json) =>
    GCAddressBookEntry(
      json['id'] as String,
      json['name'] as String,
      (json['members'] as List<dynamic>).map((e) => e as String).toList(),
    );

Map<String, dynamic> _$GCAddressBookEntryToJson(GCAddressBookEntry instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'members': instance.members,
    };

GCInvitation _$GCInvitationFromJson(Map<String, dynamic> json) => GCInvitation(
      RemoteUser.fromJson(json['inviter'] as Map<String, dynamic>),
      json['iid'] as int,
      json['name'] as String,
    );

Map<String, dynamic> _$GCInvitationToJson(GCInvitation instance) =>
    <String, dynamic>{
      'inviter': instance.inviter,
      'iid': instance.iid,
      'name': instance.name,
    };

GCMsg _$GCMsgFromJson(Map<String, dynamic> json) => GCMsg(
      json['sender_uid'] as String,
      json['sid'],
      json['msg'],
      json['timestamp'] as int,
    );

Map<String, dynamic> _$GCMsgToJson(GCMsg instance) => <String, dynamic>{
      'sid': instance.sid,
      'msg': instance.msg,
      'sender_uid': instance.senderUID,
      'timestamp': instance.timestamp,
    };

GCMsgToSend _$GCMsgToSendFromJson(Map<String, dynamic> json) => GCMsgToSend(
      json['gc'] as String,
      json['msg'] as String,
    );

Map<String, dynamic> _$GCMsgToSendToJson(GCMsgToSend instance) =>
    <String, dynamic>{
      'gc': instance.gc,
      'msg': instance.msg,
    };

GCRemoveUserArgs _$GCRemoveUserArgsFromJson(Map<String, dynamic> json) =>
    GCRemoveUserArgs(
      json['gc'] as String,
      json['uid'] as String,
    );

Map<String, dynamic> _$GCRemoveUserArgsToJson(GCRemoveUserArgs instance) =>
    <String, dynamic>{
      'gc': instance.gc,
      'uid': instance.uid,
    };

AddressBookEntry _$AddressBookEntryFromJson(Map<String, dynamic> json) =>
    AddressBookEntry(
      json['id'] as String,
      json['nick'] as String,
      name: json['name'] as String? ?? "",
      ignored: json['ignored'] as bool? ?? false,
    );

Map<String, dynamic> _$AddressBookEntryToJson(AddressBookEntry instance) =>
    <String, dynamic>{
      'id': instance.id,
      'nick': instance.nick,
      'name': instance.name,
      'ignored': instance.ignored,
    };

ShareFileArgs _$ShareFileArgsFromJson(Map<String, dynamic> json) =>
    ShareFileArgs(
      json['filename'] as String,
      json['uid'] as String,
      json['cost'] as int,
      json['description'] as String,
    );

Map<String, dynamic> _$ShareFileArgsToJson(ShareFileArgs instance) =>
    <String, dynamic>{
      'filename': instance.filename,
      'uid': instance.uid,
      'cost': instance.cost,
      'description': instance.description,
    };

UnshareFileArgs _$UnshareFileArgsFromJson(Map<String, dynamic> json) =>
    UnshareFileArgs(
      json['fid'] as String,
      json['uid'] as String?,
    );

Map<String, dynamic> _$UnshareFileArgsToJson(UnshareFileArgs instance) {
  final val = <String, dynamic>{
    'fid': instance.fid,
  };

  void writeNotNull(String key, dynamic value) {
    if (value != null) {
      val[key] = value;
    }
  }

  writeNotNull('uid', instance.uid);
  return val;
}

GetRemoteFileArgs _$GetRemoteFileArgsFromJson(Map<String, dynamic> json) =>
    GetRemoteFileArgs(
      json['uid'] as String,
      json['fid'] as String,
    );

Map<String, dynamic> _$GetRemoteFileArgsToJson(GetRemoteFileArgs instance) =>
    <String, dynamic>{
      'uid': instance.uid,
      'fid': instance.fid,
    };

FileManifest _$FileManifestFromJson(Map<String, dynamic> json) => FileManifest(
      json['index'] as int,
      json['size'] as int,
      json['hash'] as String,
    );

Map<String, dynamic> _$FileManifestToJson(FileManifest instance) =>
    <String, dynamic>{
      'index': instance.index,
      'size': instance.size,
      'hash': instance.hash,
    };

FileMetadata _$FileMetadataFromJson(Map<String, dynamic> json) => FileMetadata(
      json['version'] as int,
      json['cost'] as int,
      json['size'] as int,
      json['directory'] as String,
      json['filename'] as String,
      json['description'] as String,
      json['hash'] as String,
      (json['manifest'] as List<dynamic>)
          .map((e) => FileManifest.fromJson(e as Map<String, dynamic>))
          .toList(),
      json['signature'] as String,
      json['attributes'] as Map<String, dynamic>?,
    );

Map<String, dynamic> _$FileMetadataToJson(FileMetadata instance) =>
    <String, dynamic>{
      'version': instance.version,
      'cost': instance.cost,
      'size': instance.size,
      'directory': instance.directory,
      'filename': instance.filename,
      'description': instance.description,
      'hash': instance.hash,
      'manifest': instance.manifest,
      'signature': instance.signature,
      'attributes': instance.attributes,
    };

SharedFile _$SharedFileFromJson(Map<String, dynamic> json) => SharedFile(
      json['file_hash'] as String,
      json['fid'] as String,
      json['filename'] as String,
    );

Map<String, dynamic> _$SharedFileToJson(SharedFile instance) =>
    <String, dynamic>{
      'file_hash': instance.fileHash,
      'fid': instance.fid,
      'filename': instance.filename,
    };

SharedFileAndShares _$SharedFileAndSharesFromJson(Map<String, dynamic> json) =>
    SharedFileAndShares(
      SharedFile.fromJson(json['shared_file'] as Map<String, dynamic>),
      json['cost'] as int,
      json['global'] as bool,
      (json['shares'] as List<dynamic>).map((e) => e as String).toList(),
    );

Map<String, dynamic> _$SharedFileAndSharesToJson(
        SharedFileAndShares instance) =>
    <String, dynamic>{
      'shared_file': instance.sf,
      'cost': instance.cost,
      'global': instance.global,
      'shares': instance.shares,
    };

ReceivedFile _$ReceivedFileFromJson(Map<String, dynamic> json) => ReceivedFile(
      json['file_id'] as String,
      json['uid'] as String,
      json['disk_path'] as String,
      FileMetadata.fromJson(json['metadata'] as Map<String, dynamic>),
    );

Map<String, dynamic> _$ReceivedFileToJson(ReceivedFile instance) =>
    <String, dynamic>{
      'file_id': instance.fid,
      'uid': instance.uid,
      'disk_path': instance.diskPath,
      'metadata': instance.metadata,
    };

UserContentList _$UserContentListFromJson(Map<String, dynamic> json) =>
    UserContentList(
      json['uid'] as String,
      (json['files'] as List<dynamic>)
          .map((e) => ReceivedFile.fromJson(e as Map<String, dynamic>))
          .toList(),
    );

Map<String, dynamic> _$UserContentListToJson(UserContentList instance) =>
    <String, dynamic>{
      'uid': instance.uid,
      'files': instance.files,
    };

PayTipArgs _$PayTipArgsFromJson(Map<String, dynamic> json) => PayTipArgs(
      json['uid'] as String,
      (json['amount'] as num).toDouble(),
    );

Map<String, dynamic> _$PayTipArgsToJson(PayTipArgs instance) =>
    <String, dynamic>{
      'uid': instance.uid,
      'amount': instance.amount,
    };

PostMetadata _$PostMetadataFromJson(Map<String, dynamic> json) => PostMetadata(
      json['version'] as int,
      Map<String, String>.from(json['attributes'] as Map),
    );

Map<String, dynamic> _$PostMetadataToJson(PostMetadata instance) =>
    <String, dynamic>{
      'version': instance.version,
      'attributes': instance.attributes,
    };

PostMetadataStatus _$PostMetadataStatusFromJson(Map<String, dynamic> json) =>
    PostMetadataStatus(
      json['version'] as int,
      json['from'] as String,
      json['link'] as String,
      Map<String, String>.from(json['attributes'] as Map),
    );

Map<String, dynamic> _$PostMetadataStatusToJson(PostMetadataStatus instance) =>
    <String, dynamic>{
      'version': instance.version,
      'from': instance.from,
      'link': instance.link,
      'attributes': instance.attributes,
    };

PostReceived _$PostReceivedFromJson(Map<String, dynamic> json) => PostReceived(
      json['uid'] as String,
      PostMetadata.fromJson(json['post_meta'] as Map<String, dynamic>),
    );

Map<String, dynamic> _$PostReceivedToJson(PostReceived instance) =>
    <String, dynamic>{
      'uid': instance.uid,
      'post_meta': instance.postMeta,
    };

PostSummary _$PostSummaryFromJson(Map<String, dynamic> json) => PostSummary(
      json['id'] as String,
      json['from'] as String,
      json['author_id'] as String,
      json['author_nick'] as String,
      DateTime.parse(json['date'] as String),
      DateTime.parse(json['last_status_ts'] as String),
      json['title'] as String,
    );

Map<String, dynamic> _$PostSummaryToJson(PostSummary instance) =>
    <String, dynamic>{
      'id': instance.id,
      'from': instance.from,
      'author_id': instance.authorID,
      'author_nick': instance.authorNick,
      'date': instance.date.toIso8601String(),
      'last_status_ts': instance.lastStatusTS.toIso8601String(),
      'title': instance.title,
    };

ReadPostArgs _$ReadPostArgsFromJson(Map<String, dynamic> json) => ReadPostArgs(
      json['from'] as String,
      json['pid'] as String,
    );

Map<String, dynamic> _$ReadPostArgsToJson(ReadPostArgs instance) =>
    <String, dynamic>{
      'from': instance.from,
      'pid': instance.pid,
    };

CommentPostArgs _$CommentPostArgsFromJson(Map<String, dynamic> json) =>
    CommentPostArgs(
      json['from'] as String,
      json['pid'] as String,
      json['comment'] as String,
      json['parent'] as String?,
    );

Map<String, dynamic> _$CommentPostArgsToJson(CommentPostArgs instance) =>
    <String, dynamic>{
      'from': instance.from,
      'pid': instance.pid,
      'comment': instance.comment,
      'parent': instance.parent,
    };

PostStatusReceived _$PostStatusReceivedFromJson(Map<String, dynamic> json) =>
    PostStatusReceived(
      json['post_from'] as String,
      json['pid'] as String,
      json['status_from'] as String,
      PostMetadataStatus.fromJson(json['status'] as Map<String, dynamic>),
      json['mine'] as bool,
    );

Map<String, dynamic> _$PostStatusReceivedToJson(PostStatusReceived instance) =>
    <String, dynamic>{
      'post_from': instance.postFrom,
      'pid': instance.pid,
      'status_from': instance.statusFrom,
      'status': instance.status,
      'mine': instance.mine,
    };

MediateIDArgs _$MediateIDArgsFromJson(Map<String, dynamic> json) =>
    MediateIDArgs(
      json['mediator'] as String,
      json['target'] as String,
    );

Map<String, dynamic> _$MediateIDArgsToJson(MediateIDArgs instance) =>
    <String, dynamic>{
      'mediator': instance.mediator,
      'target': instance.target,
    };

PostActionArgs _$PostActionArgsFromJson(Map<String, dynamic> json) =>
    PostActionArgs(
      json['from'] as String,
      json['pid'] as String,
    );

Map<String, dynamic> _$PostActionArgsToJson(PostActionArgs instance) =>
    <String, dynamic>{
      'from': instance.from,
      'pid': instance.pid,
    };

OutstandingFileDownload _$OutstandingFileDownloadFromJson(
        Map<String, dynamic> json) =>
    OutstandingFileDownload(
      json['uid'] as String,
      json['fid'] as String,
      json['completed_name'] as String,
      json['metadata'] == null
          ? null
          : FileMetadata.fromJson(json['metadata'] as Map<String, dynamic>),
      (json['invoices'] as Map<String, dynamic>?)?.map(
            (k, e) => MapEntry(int.parse(k), e as String),
          ) ??
          {},
      (json['chunkstates'] as Map<String, dynamic>?)?.map(
            (k, e) => MapEntry(int.parse(k), e as String),
          ) ??
          {},
    );

Map<String, dynamic> _$OutstandingFileDownloadToJson(
        OutstandingFileDownload instance) =>
    <String, dynamic>{
      'uid': instance.uid,
      'fid': instance.fid,
      'completed_name': instance.completedName,
      'metadata': instance.metadata,
      'invoices': instance.invoices.map((k, e) => MapEntry(k.toString(), e)),
      'chunkstates':
          instance.chunkStates.map((k, e) => MapEntry(k.toString(), e)),
    };

FileDownloadProgress _$FileDownloadProgressFromJson(
        Map<String, dynamic> json) =>
    FileDownloadProgress(
      json['uid'] as String,
      json['fid'] as String,
      FileMetadata.fromJson(json['metadata'] as Map<String, dynamic>),
      json['nb_missing_chunks'] as int,
    );

Map<String, dynamic> _$FileDownloadProgressToJson(
        FileDownloadProgress instance) =>
    <String, dynamic>{
      'uid': instance.uid,
      'fid': instance.fid,
      'metadata': instance.metadata,
      'nb_missing_chunks': instance.nbMissingChunks,
    };

LNChain _$LNChainFromJson(Map<String, dynamic> json) => LNChain(
      json['chain'] as String,
      json['network'] as String,
    );

Map<String, dynamic> _$LNChainToJson(LNChain instance) => <String, dynamic>{
      'chain': instance.chain,
      'network': instance.network,
    };

LNInfo _$LNInfoFromJson(Map<String, dynamic> json) => LNInfo(
      json['identity_pubkey'] as String,
      json['version'] as String,
      json['num_active_channels'] as int? ?? 0,
      json['num_inactive_channels'] as int? ?? 0,
      json['num_pending_channels'] as int? ?? 0,
      json['synced_to_chain'] as bool? ?? false,
      json['synced_to_graph'] as bool? ?? false,
      json['block_height'] as int,
      json['block_hash'] as String,
      (json['chains'] as List<dynamic>)
          .map((e) => LNChain.fromJson(e as Map<String, dynamic>))
          .toList(),
    );

Map<String, dynamic> _$LNInfoToJson(LNInfo instance) => <String, dynamic>{
      'identity_pubkey': instance.identityPubkey,
      'version': instance.version,
      'num_active_channels': instance.numActiveChannels,
      'num_inactive_channels': instance.numInactiveChannels,
      'num_pending_channels': instance.numPendingChannels,
      'synced_to_chain': instance.syncedToChain,
      'synced_to_graph': instance.syncedToGraph,
      'block_height': instance.blockHeight,
      'block_hash': instance.blockHash,
      'chains': instance.chains,
    };

LNChannel _$LNChannelFromJson(Map<String, dynamic> json) => LNChannel(
      json['active'] as bool? ?? false,
      json['remote_pubkey'] as String,
      json['channel_point'] as String,
      json['chan_id'] as int,
      json['capacity'] as int,
      json['local_balance'] as int? ?? 0,
      json['remote_balance'] as int? ?? 0,
    );

Map<String, dynamic> _$LNChannelToJson(LNChannel instance) => <String, dynamic>{
      'active': instance.active,
      'remote_pubkey': instance.remotePubkey,
      'channel_point': instance.channelPoint,
      'chan_id': instance.chanID,
      'capacity': instance.capacity,
      'local_balance': instance.localBalance,
      'remote_balance': instance.remoteBalance,
    };

LNPendingChannel _$LNPendingChannelFromJson(Map<String, dynamic> json) =>
    LNPendingChannel(
      json['remote_node_pub'] as String,
      json['channel_point'] as String,
      json['capacity'] as int,
      json['local_balance'] as int? ?? 0,
      json['remote_balance'] as int? ?? 0,
      json['initiator'] as int? ?? 0,
    );

Map<String, dynamic> _$LNPendingChannelToJson(LNPendingChannel instance) =>
    <String, dynamic>{
      'remote_node_pub': instance.remoteNodePub,
      'channel_point': instance.channelPoint,
      'capacity': instance.capacity,
      'local_balance': instance.localBalance,
      'remote_balance': instance.remoteBalance,
      'initiator': instance.initiator,
    };

LNPendingOpenChannel _$LNPendingOpenChannelFromJson(
        Map<String, dynamic> json) =>
    LNPendingOpenChannel(
      json['confirmation_height'] as int? ?? 0,
      json['commit_fee'] as int? ?? 0,
      json['confirmation_size'] as int? ?? 0,
      json['fee_per_kb'] as int? ?? 0,
      LNPendingChannel.fromJson(json['channel'] as Map<String, dynamic>),
    );

Map<String, dynamic> _$LNPendingOpenChannelToJson(
        LNPendingOpenChannel instance) =>
    <String, dynamic>{
      'channel': instance.channel,
      'confirmation_height': instance.confirmationHeight,
      'commit_fee': instance.commitFee,
      'confirmation_size': instance.commitSize,
      'fee_per_kb': instance.feePerKb,
    };

LNWaitingCloseChannel _$LNWaitingCloseChannelFromJson(
        Map<String, dynamic> json) =>
    LNWaitingCloseChannel(
      LNPendingChannel.fromJson(json['channel'] as Map<String, dynamic>),
    );

Map<String, dynamic> _$LNWaitingCloseChannelToJson(
        LNWaitingCloseChannel instance) =>
    <String, dynamic>{
      'channel': instance.channel,
    };

LNPendingForceClosingChannel _$LNPendingForceClosingChannelFromJson(
        Map<String, dynamic> json) =>
    LNPendingForceClosingChannel(
      LNPendingChannel.fromJson(json['channel'] as Map<String, dynamic>),
      json['closing_txid'] as String? ?? '',
      json['maturityHeight'] as int? ?? 0,
      json['blocksTilMaturity'] as int? ?? 0,
      json['recoveredBalance'] as int? ?? 0,
    );

Map<String, dynamic> _$LNPendingForceClosingChannelToJson(
        LNPendingForceClosingChannel instance) =>
    <String, dynamic>{
      'channel': instance.channel,
      'closing_txid': instance.closingTxid,
      'maturityHeight': instance.maturityHeight,
      'blocksTilMaturity': instance.blocksTilMaturity,
      'recoveredBalance': instance.recoveredBalance,
    };

LNPendingChannelsList _$LNPendingChannelsListFromJson(
        Map<String, dynamic> json) =>
    LNPendingChannelsList(
      (json['pending_open_channels'] as List<dynamic>?)
              ?.map((e) =>
                  LNPendingOpenChannel.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      (json['pending_force_closing_channels'] as List<dynamic>?)
              ?.map((e) => LNPendingForceClosingChannel.fromJson(
                  e as Map<String, dynamic>))
              .toList() ??
          [],
      (json['waiting_close_channels'] as List<dynamic>?)
              ?.map((e) =>
                  LNWaitingCloseChannel.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );

Map<String, dynamic> _$LNPendingChannelsListToJson(
        LNPendingChannelsList instance) =>
    <String, dynamic>{
      'pending_open_channels': instance.pendingOpen,
      'pending_force_closing_channels': instance.pendingForceClose,
      'waiting_close_channels': instance.waitingClose,
    };

LNGenInvoiceRequest _$LNGenInvoiceRequestFromJson(Map<String, dynamic> json) =>
    LNGenInvoiceRequest(
      json['memo'] as String,
      json['value'] as int,
    );

Map<String, dynamic> _$LNGenInvoiceRequestToJson(
        LNGenInvoiceRequest instance) =>
    <String, dynamic>{
      'memo': instance.memo,
      'value': instance.value,
    };

LNGenInvoiceResponse _$LNGenInvoiceResponseFromJson(
        Map<String, dynamic> json) =>
    LNGenInvoiceResponse(
      json['r_hash'] as String,
      json['payment_request'] as String,
    );

Map<String, dynamic> _$LNGenInvoiceResponseToJson(
        LNGenInvoiceResponse instance) =>
    <String, dynamic>{
      'r_hash': instance.rhash,
      'payment_request': instance.paymentRequest,
    };

LNPayInvoiceResponse _$LNPayInvoiceResponseFromJson(
        Map<String, dynamic> json) =>
    LNPayInvoiceResponse(
      json['payment_error'] as String? ?? '',
      base64ToHex(json['payment_preimage'] as String),
      base64ToHex(json['payment_hash'] as String),
    );

Map<String, dynamic> _$LNPayInvoiceResponseToJson(
        LNPayInvoiceResponse instance) =>
    <String, dynamic>{
      'payment_error': instance.paymentError,
      'payment_preimage': instance.preimage,
      'payment_hash': instance.paymentHash,
    };

LNQueryRouteRequest _$LNQueryRouteRequestFromJson(Map<String, dynamic> json) =>
    LNQueryRouteRequest(
      json['pub_key'] as String,
      json['amt'] as int,
    );

Map<String, dynamic> _$LNQueryRouteRequestToJson(
        LNQueryRouteRequest instance) =>
    <String, dynamic>{
      'pub_key': instance.pubkey,
      'amt': instance.amount,
    };

LNHop _$LNHopFromJson(Map<String, dynamic> json) => LNHop(
      json['chan_id'] as int? ?? 0,
      json['chan_capacity'] as int? ?? 0,
      json['pub_key'] as String,
    );

Map<String, dynamic> _$LNHopToJson(LNHop instance) => <String, dynamic>{
      'chan_id': instance.chanId,
      'chan_capacity': instance.chanCapacity,
      'pub_key': instance.pubkey,
    };

LNRoute _$LNRouteFromJson(Map<String, dynamic> json) => LNRoute(
      json['total_time_lock'] as int,
      json['total_fees'] as int? ?? 0,
      (json['hops'] as List<dynamic>?)
              ?.map((e) => LNHop.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );

Map<String, dynamic> _$LNRouteToJson(LNRoute instance) => <String, dynamic>{
      'total_time_lock': instance.totalTimeLock,
      'total_fees': instance.totalFees,
      'hops': instance.hops,
    };

LNQueryRouteResponse _$LNQueryRouteResponseFromJson(
        Map<String, dynamic> json) =>
    LNQueryRouteResponse(
      (json['routes'] as List<dynamic>?)
              ?.map((e) => LNRoute.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      (json['success_prob'] as num?)?.toDouble() ?? 0,
    );

Map<String, dynamic> _$LNQueryRouteResponseToJson(
        LNQueryRouteResponse instance) =>
    <String, dynamic>{
      'routes': instance.routes,
      'success_prob': instance.successProb,
    };

LNGetNodeInfoRequest _$LNGetNodeInfoRequestFromJson(
        Map<String, dynamic> json) =>
    LNGetNodeInfoRequest(
      json['pub_key'] as String,
      json['include_channels'] as bool? ?? false,
    );

Map<String, dynamic> _$LNGetNodeInfoRequestToJson(
        LNGetNodeInfoRequest instance) =>
    <String, dynamic>{
      'pub_key': instance.pubkey,
      'include_channels': instance.includeChannels,
    };

LNNode _$LNNodeFromJson(Map<String, dynamic> json) => LNNode(
      json['pub_key'] as String,
      json['alias'] as String? ?? '',
      json['last_update'] as int? ?? 0,
    );

Map<String, dynamic> _$LNNodeToJson(LNNode instance) => <String, dynamic>{
      'pub_key': instance.pubkey,
      'alias': instance.alias,
      'last_update': instance.lastUpdate,
    };

LNRoutingPolicy _$LNRoutingPolicyFromJson(Map<String, dynamic> json) =>
    LNRoutingPolicy(
      json['disabled'] as bool? ?? false,
      json['last_update'] as int? ?? 0,
    );

Map<String, dynamic> _$LNRoutingPolicyToJson(LNRoutingPolicy instance) =>
    <String, dynamic>{
      'disabled': instance.disabled,
      'last_update': instance.lastUpdate,
    };

LNChannelEdge _$LNChannelEdgeFromJson(Map<String, dynamic> json) =>
    LNChannelEdge(
      json['channel_id'] as int? ?? 0,
      json['chan_point'] as String,
      json['last_update'] as int? ?? 0,
      json['node1_pub'] as String,
      json['node2_pub'] as String,
      json['capacity'] as int? ?? 0,
      LNRoutingPolicy.fromJson(json['node1_policy'] as Map<String, dynamic>),
      LNRoutingPolicy.fromJson(json['node2_policy'] as Map<String, dynamic>),
    );

Map<String, dynamic> _$LNChannelEdgeToJson(LNChannelEdge instance) =>
    <String, dynamic>{
      'channel_id': instance.channelID,
      'chan_point': instance.channelPoint,
      'last_update': instance.lastUpdate,
      'node1_pub': instance.node1Pub,
      'node2_pub': instance.node2Pub,
      'capacity': instance.capacity,
      'node1_policy': instance.node1Policy,
      'node2_policy': instance.node2Policy,
    };

LNGetNodeInfoResponse _$LNGetNodeInfoResponseFromJson(
        Map<String, dynamic> json) =>
    LNGetNodeInfoResponse(
      LNNode.fromJson(json['node'] as Map<String, dynamic>),
      json['num_channels'] as int,
      json['total_capacity'] as int? ?? 0,
      (json['channels'] as List<dynamic>?)
              ?.map((e) => LNChannelEdge.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );

Map<String, dynamic> _$LNGetNodeInfoResponseToJson(
        LNGetNodeInfoResponse instance) =>
    <String, dynamic>{
      'node': instance.node,
      'num_channels': instance.numChannels,
      'total_capacity': instance.totalCapacity,
      'channels': instance.channels,
    };

LNChannelBalance _$LNChannelBalanceFromJson(Map<String, dynamic> json) =>
    LNChannelBalance(
      json['balance'] as int? ?? 0,
      json['pending_open_balance'] as int? ?? 0,
      json['max_inbound_amount'] as int? ?? 0,
      json['max_outbound_amount'] as int? ?? 0,
    );

Map<String, dynamic> _$LNChannelBalanceToJson(LNChannelBalance instance) =>
    <String, dynamic>{
      'balance': instance.balance,
      'pending_open_balance': instance.pendingOpenBalance,
      'max_inbound_amount': instance.maxInboundAmount,
      'max_outbound_amount': instance.maxOutboundAmount,
    };

LNWalletBalance _$LNWalletBalanceFromJson(Map<String, dynamic> json) =>
    LNWalletBalance(
      json['total_balance'] as int? ?? 0,
      json['confirmed_balance'] as int? ?? 0,
      json['unconfirmed_balance'] as int? ?? 0,
    );

Map<String, dynamic> _$LNWalletBalanceToJson(LNWalletBalance instance) =>
    <String, dynamic>{
      'total_balance': instance.totalBalance,
      'confirmed_balance': instance.confirmedBalance,
      'unconfirmed_balance': instance.unconfirmedBalance,
    };

LNBalances _$LNBalancesFromJson(Map<String, dynamic> json) => LNBalances(
      LNChannelBalance.fromJson(json['channel'] as Map<String, dynamic>),
      LNWalletBalance.fromJson(json['wallet'] as Map<String, dynamic>),
    );

Map<String, dynamic> _$LNBalancesToJson(LNBalances instance) =>
    <String, dynamic>{
      'channel': instance.channel,
      'wallet': instance.wallet,
    };

LNDecodedInvoice _$LNDecodedInvoiceFromJson(Map<String, dynamic> json) =>
    LNDecodedInvoice(
      json['destination'] as String,
      json['payment_hash'] as String,
      json['numAtoms'] as int? ?? 0,
      json['expiry'] as int? ?? 3600,
      json['description'] as String? ?? '',
      json['timestamp'] as int? ?? 0,
      json['num_m_atoms'] as int? ?? 0,
    );

Map<String, dynamic> _$LNDecodedInvoiceToJson(LNDecodedInvoice instance) =>
    <String, dynamic>{
      'destination': instance.destination,
      'payment_hash': instance.paymentHash,
      'numAtoms': instance.numAtoms,
      'num_m_atoms': instance.numMAtoms,
      'expiry': instance.expiry,
      'description': instance.description,
      'timestamp': instance.timestamp,
    };

LNPayInvoiceRequest _$LNPayInvoiceRequestFromJson(Map<String, dynamic> json) =>
    LNPayInvoiceRequest(
      json['payment_request'] as String,
      json['amount'] as int,
    );

Map<String, dynamic> _$LNPayInvoiceRequestToJson(
        LNPayInvoiceRequest instance) =>
    <String, dynamic>{
      'payment_request': instance.paymentRequest,
      'amount': instance.amount,
    };

LNPeer _$LNPeerFromJson(Map<String, dynamic> json) => LNPeer(
      json['pub_key'] as String,
      json['address'] as String,
      json['inbound'] as bool? ?? false,
    );

Map<String, dynamic> _$LNPeerToJson(LNPeer instance) => <String, dynamic>{
      'pub_key': instance.pubkey,
      'address': instance.address,
      'inbound': instance.inbound,
    };

LNOpenChannelRequest _$LNOpenChannelRequestFromJson(
        Map<String, dynamic> json) =>
    LNOpenChannelRequest(
      json['node_pubkey'] as String,
      json['local_funding_amount'] as int,
      json['push_atoms'] as int,
    );

Map<String, dynamic> _$LNOpenChannelRequestToJson(
        LNOpenChannelRequest instance) =>
    <String, dynamic>{
      'node_pubkey': hexToBase64(instance.nodePubkey),
      'local_funding_amount': instance.localFundingAmount,
      'push_atoms': instance.pushAtoms,
    };

LNChannelPoint_FundingTxidStr _$LNChannelPoint_FundingTxidStrFromJson(
        Map<String, dynamic> json) =>
    LNChannelPoint_FundingTxidStr(
      json['fundingTxidStr'] as String? ?? '',
    );

Map<String, dynamic> _$LNChannelPoint_FundingTxidStrToJson(
        LNChannelPoint_FundingTxidStr instance) =>
    <String, dynamic>{
      'fundingTxidStr': instance.fundingTxidStr,
    };

LNChannelPoint_FundingTxidBytes _$LNChannelPoint_FundingTxidBytesFromJson(
        Map<String, dynamic> json) =>
    LNChannelPoint_FundingTxidBytes(
      json['fundingTxidBytes'] as String? ?? '',
    );

Map<String, dynamic> _$LNChannelPoint_FundingTxidBytesToJson(
        LNChannelPoint_FundingTxidBytes instance) =>
    <String, dynamic>{
      'fundingTxidBytes': instance.fundingTxidBytes,
    };

LNChannelPoint _$LNChannelPointFromJson(Map<String, dynamic> json) =>
    LNChannelPoint(
      json['txid'],
      json['output_index'] as int? ?? 0,
    );

Map<String, dynamic> _$LNChannelPointToJson(LNChannelPoint instance) =>
    <String, dynamic>{
      'txid': instance.txid,
      'output_index': instance.outputIndex,
    };

LNCloseChannelRequest _$LNCloseChannelRequestFromJson(
        Map<String, dynamic> json) =>
    LNCloseChannelRequest(
      LNChannelPoint.fromJson(json['channel_point'] as Map<String, dynamic>),
      json['force'] as bool,
    );

Map<String, dynamic> _$LNCloseChannelRequestToJson(
        LNCloseChannelRequest instance) =>
    <String, dynamic>{
      'channel_point': instance.channelPoint,
      'force': instance.force,
    };

LNTryExternalDcrlnd _$LNTryExternalDcrlndFromJson(Map<String, dynamic> json) =>
    LNTryExternalDcrlnd(
      json['rpc_host'] as String,
      json['tls_cert_path'] as String,
      json['macaroon_path'] as String,
    );

Map<String, dynamic> _$LNTryExternalDcrlndToJson(
        LNTryExternalDcrlnd instance) =>
    <String, dynamic>{
      'rpc_host': instance.rpcHost,
      'tls_cert_path': instance.tlsCertPath,
      'macaroon_path': instance.macaroonPath,
    };

LNInitDcrlnd _$LNInitDcrlndFromJson(Map<String, dynamic> json) => LNInitDcrlnd(
      json['root_dir'] as String,
      json['network'] as String,
      json['password'] as String,
    );

Map<String, dynamic> _$LNInitDcrlndToJson(LNInitDcrlnd instance) =>
    <String, dynamic>{
      'root_dir': instance.rootDir,
      'network': instance.network,
      'password': instance.password,
    };

LNNewWalletSeed _$LNNewWalletSeedFromJson(Map<String, dynamic> json) =>
    LNNewWalletSeed(
      json['seed'] as String,
      json['rpc_host'] as String,
    );

Map<String, dynamic> _$LNNewWalletSeedToJson(LNNewWalletSeed instance) =>
    <String, dynamic>{
      'seed': instance.seed,
      'rpc_host': instance.rpcHost,
    };

LNInitialChainSyncUpdate _$LNInitialChainSyncUpdateFromJson(
        Map<String, dynamic> json) =>
    LNInitialChainSyncUpdate(
      json['block_height'] as int? ?? 0,
      base64ToHex(json['block_hash'] as String),
      json['block_timestamp'] as int? ?? 0,
      json['synced'] as bool? ?? false,
    );

Map<String, dynamic> _$LNInitialChainSyncUpdateToJson(
        LNInitialChainSyncUpdate instance) =>
    <String, dynamic>{
      'block_height': instance.blockHeight,
      'block_hash': instance.blockHash,
      'block_timestamp': instance.blockTimestamp,
      'synced': instance.synced,
    };

LNReqChannelArgs _$LNReqChannelArgsFromJson(Map<String, dynamic> json) =>
    LNReqChannelArgs(
      json['server'] as String,
      json['key'] as String,
      json['chan_size'] as int,
      json['certificates'] as String,
    );

Map<String, dynamic> _$LNReqChannelArgsToJson(LNReqChannelArgs instance) =>
    <String, dynamic>{
      'server': instance.server,
      'key': instance.key,
      'chan_size': instance.chanSize,
      'certificates': instance.certificates,
    };

LNReqChannelEstValue _$LNReqChannelEstValueFromJson(
        Map<String, dynamic> json) =>
    LNReqChannelEstValue(
      json['amount'] as int? ?? 0,
    );

Map<String, dynamic> _$LNReqChannelEstValueToJson(
        LNReqChannelEstValue instance) =>
    <String, dynamic>{
      'amount': instance.amount,
    };

ConfirmFileDownload _$ConfirmFileDownloadFromJson(Map<String, dynamic> json) =>
    ConfirmFileDownload(
      json['uid'] as String,
      json['fid'] as String,
      FileMetadata.fromJson(json['metadata'] as Map<String, dynamic>),
    );

Map<String, dynamic> _$ConfirmFileDownloadToJson(
        ConfirmFileDownload instance) =>
    <String, dynamic>{
      'uid': instance.uid,
      'fid': instance.fid,
      'metadata': instance.metadata,
    };

ConfirmFileDownloadReply _$ConfirmFileDownloadReplyFromJson(
        Map<String, dynamic> json) =>
    ConfirmFileDownloadReply(
      json['fid'] as String,
      json['reply'] as bool,
    );

Map<String, dynamic> _$ConfirmFileDownloadReplyToJson(
        ConfirmFileDownloadReply instance) =>
    <String, dynamic>{
      'fid': instance.fid,
      'reply': instance.reply,
    };

SendFileArgs _$SendFileArgsFromJson(Map<String, dynamic> json) => SendFileArgs(
      json['uid'] as String,
      json['filepath'] as String,
    );

Map<String, dynamic> _$SendFileArgsToJson(SendFileArgs instance) =>
    <String, dynamic>{
      'uid': instance.uid,
      'filepath': instance.filepath,
    };

UserPayStats _$UserPayStatsFromJson(Map<String, dynamic> json) => UserPayStats(
      json['total_sent'] as int,
      json['total_received'] as int,
    );

Map<String, dynamic> _$UserPayStatsToJson(UserPayStats instance) =>
    <String, dynamic>{
      'total_sent': instance.totalSent,
      'total_received': instance.totalReceived,
    };

PayStatsSummary _$PayStatsSummaryFromJson(Map<String, dynamic> json) =>
    PayStatsSummary(
      json['prefix'] as String,
      json['total'] as int,
    );

Map<String, dynamic> _$PayStatsSummaryToJson(PayStatsSummary instance) =>
    <String, dynamic>{
      'prefix': instance.prefix,
      'total': instance.total,
    };

PostListItem _$PostListItemFromJson(Map<String, dynamic> json) => PostListItem(
      json['id'] as String,
      json['title'] as String,
    );

Map<String, dynamic> _$PostListItemToJson(PostListItem instance) =>
    <String, dynamic>{
      'id': instance.id,
      'title': instance.title,
    };

UserPostList _$UserPostListFromJson(Map<String, dynamic> json) => UserPostList(
      json['uid'] as String,
      (json['posts'] as List<dynamic>)
          .map((e) => PostListItem.fromJson(e as Map<String, dynamic>))
          .toList(),
    );

Map<String, dynamic> _$UserPostListToJson(UserPostList instance) =>
    <String, dynamic>{
      'uid': instance.uid,
      'posts': instance.posts,
    };

LocalRenameArgs _$LocalRenameArgsFromJson(Map<String, dynamic> json) =>
    LocalRenameArgs(
      json['id'] as String,
      json['new_name'] as String,
      json['is_gc'] as bool? ?? false,
    );

Map<String, dynamic> _$LocalRenameArgsToJson(LocalRenameArgs instance) =>
    <String, dynamic>{
      'id': instance.id,
      'new_name': instance.newName,
      'is_gc': instance.isGC,
    };
