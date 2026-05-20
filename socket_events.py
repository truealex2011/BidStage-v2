from flask import session, request
from flask_socketio import join_room, leave_room, emit, disconnect


_socketio = None


LOT_EVENTS = {'new_bid', 'timer_extended', 'auction_ended', 'new_top_bid', 'bid_verified', 'share_verified', 'chat_message'}
USER_EVENTS = {'outbid', 'bid_cancelled', 'payment_due', 'payment_completed', 'escrow_released', 'ticket_delivered', 'chat_message', 'bid_verified', 'otp_required', 'notification_new', 'auction_runner_up', 'cascade_advanced', 'seller_paid', 'seller_payment_received'}

_lot_viewers = {}
_lot_viewers_lock = __import__('threading').Lock()


def _viewer_count(lot_id):
    with _lot_viewers_lock:
        return _lot_viewers.get(int(lot_id), 0)


def init_socket_events(socketio):
    global _socketio
    _socketio = socketio

    @socketio.on('connect')
    def _on_connect():
        user_id = session.get('user_id')
        if user_id is not None:
            join_room('user_{}'.format(int(user_id)))
            register_online(user_id, request.sid)
            _socketio.emit('online_count', {'count': online_count()})

    @socketio.on('disconnect')
    def _on_disconnect():
        unregister_online(request.sid)
        _socketio.emit('online_count', {'count': online_count()})
        return None

    @socketio.on('join_lot')
    def _on_join_lot(data):
        if 'user_id' not in session:
            emit('error', {'reason': 'unauthorized'})
            disconnect()
            return
        try:
            lot_id = int((data or {}).get('lot_id'))
        except (TypeError, ValueError):
            emit('error', {'reason': 'invalid_lot_id'})
            return
        join_room('lot_{}'.format(lot_id))
        _add_sid_to_lot(lot_id, request.sid, session['user_id'])
        _socketio.emit('lot_viewers', {'lot_id': lot_id, 'count': lot_viewers_count(lot_id)}, to='lot_{}'.format(lot_id))

    @socketio.on('leave_lot')
    def _on_leave_lot(data):
        try:
            lot_id = int((data or {}).get('lot_id'))
        except (TypeError, ValueError):
            return
        leave_room('lot_{}'.format(lot_id))
        _remove_sid_from_lot(lot_id, request.sid)
        _socketio.emit('lot_viewers', {'lot_id': lot_id, 'count': lot_viewers_count(lot_id)}, to='lot_{}'.format(lot_id))


def emit_to_lot(lot_id, event, payload):
    if event not in LOT_EVENTS:
        raise ValueError('event {} not allowed in lot rooms'.format(event))
    if _socketio is None:
        return
    _socketio.emit(event, payload, to='lot_{}'.format(int(lot_id)))


def emit_to_user(user_id, event, payload):
    if event not in USER_EVENTS:
        raise ValueError('event {} not allowed in user rooms'.format(event))
    if _socketio is None:
        return
    _socketio.emit(event, payload, to='user_{}'.format(int(user_id)))


def get_socketio():
    return _socketio



_online_sids = {}
_online_lock = __import__('threading').Lock()

_lot_watchers = {}
_lot_watchers_lock = __import__('threading').Lock()


def online_count():
    with _online_lock:
        return len(set(_online_sids.values()))


def register_online(user_id, sid):
    with _online_lock:
        _online_sids[sid] = int(user_id)


def unregister_online(sid):
    user_id = None
    with _online_lock:
        user_id = _online_sids.pop(sid, None)
    if user_id is not None:
        _remove_sid_from_all_lots(sid)


def _add_sid_to_lot(lot_id, sid, user_id):
    with _lot_watchers_lock:
        if lot_id not in _lot_watchers:
            _lot_watchers[lot_id] = {}
        _lot_watchers[lot_id][sid] = int(user_id)


def _remove_sid_from_lot(lot_id, sid):
    with _lot_watchers_lock:
        if lot_id in _lot_watchers:
            _lot_watchers[lot_id].pop(sid, None)
            if not _lot_watchers[lot_id]:
                del _lot_watchers[lot_id]


def _remove_sid_from_all_lots(sid):
    affected = []
    with _lot_watchers_lock:
        for lot_id in list(_lot_watchers.keys()):
            if sid in _lot_watchers[lot_id]:
                del _lot_watchers[lot_id][sid]
                affected.append(lot_id)
                if not _lot_watchers[lot_id]:
                    del _lot_watchers[lot_id]
    for lot_id in affected:
        if _socketio is not None:
            _socketio.emit('lot_viewers', {'lot_id': lot_id, 'count': lot_viewers_count(lot_id)}, to='lot_{}'.format(lot_id))


def lot_viewers_count(lot_id):
    with _lot_watchers_lock:
        return len(set(_lot_watchers.get(lot_id, {}).values()))
