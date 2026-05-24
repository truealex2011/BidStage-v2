import os
import sys
import logging
from flask import Flask
from flask_socketio import SocketIO
from apscheduler.schedulers.background import BackgroundScheduler
from dotenv import load_dotenv

import models
import socket_events
import payments
import notify
from routes import bp as routes_bp


load_dotenv()


logging.basicConfig(level=logging.INFO, format='%(asctime)s %(levelname)s %(name)s %(message)s')
logger = logging.getLogger('bidstage.app')


def _require_env(name):
    value = os.environ.get(name)
    if not value:
        sys.stderr.write('configuration error: {} is required\n'.format(name))
        sys.exit(2)
    return value


def create_app():
    _require_env('DATABASE_URL')
    app = Flask(__name__, static_folder='static', template_folder='templates')
    app.config['SECRET_KEY'] = os.environ.get('SECRET_KEY', 'dev_secret_change_me')
    app.config['SESSION_COOKIE_HTTPONLY'] = True
    app.config['MAX_CONTENT_LENGTH'] = 8 * 1024 * 1024
    app.config['SESSION_COOKIE_SAMESITE'] = 'Lax'
    app.config['TEMPLATES_AUTO_RELOAD'] = True
    app.jinja_env.auto_reload = True
    app.config['SEND_FILE_MAX_AGE_DEFAULT'] = 0
    app.register_blueprint(routes_bp)
    return app


def create_socketio(app):
    async_mode = os.environ.get('SOCKETIO_ASYNC_MODE', 'threading')
    socketio = SocketIO(app, cors_allowed_origins='*', async_mode=async_mode, manage_session=False)
    socket_events.init_socket_events(socketio)
    return socketio


def _bootstrap_database():
    with models.get_conn() as conn:
        models.init_schema(conn)
        models.ensure_balance_column(conn)
        models.ensure_payment_methods_table(conn)
        models.ensure_password_column(conn)
        models.ensure_watchlist_table(conn)
        models.ensure_seller_columns(conn)
        models.ensure_proxy_bid_columns(conn)
        models.ensure_escrow_columns(conn)
        models.ensure_reviews_table(conn)
        models.ensure_lot_events_table(conn)
        notify.ensure_notifications_table(conn)
        notify.ensure_bot_user(conn)
        models.ensure_push_subscriptions_table(conn)
        conn.commit()


def _cleanup_broken_images():
    """Сброс битых ссылок image_url, указывающих на /static/lot_images/lot_*
    которые могли потеряться при ребилде Amvera (картинки сохранялись в
    эфемерной static-папке до миграции на /data/lot_images)."""
    try:
        with models.get_conn() as conn:
            with conn.cursor() as cur:
                cur.execute(
                    "UPDATE lots SET image_url = NULL "
                    "WHERE image_url LIKE %s",
                    ('/static/lot_images/lot\\_%',),
                )
                cleared = cur.rowcount
            conn.commit()
        if cleared:
            logger.info('cleanup_broken_images cleared=%s', cleared)
    except Exception as _e:
        logger.warning('cleanup_broken_images failed: %s', _e)


def _start_scheduler():
    scheduler = BackgroundScheduler(timezone='UTC')
    scheduler.add_job(lambda: payments.end_expired_lots(scheduler), 'interval', seconds=30, id='end_expired_lots')
    scheduler.add_job(lambda: payments.cascade_expired_payments(scheduler), 'interval', seconds=30, id='cascade_expired_payments')
    scheduler.start()
    return scheduler


app = create_app()
socketio = create_socketio(app)


# Bootstrap БД и шедулер на любом старте — нужно для запуска под gunicorn/replit
try:
    _bootstrap_database()
    _cleanup_broken_images()
except Exception as _e:
    logger.exception('database bootstrap failed: %s', _e)

scheduler = None
try:
    scheduler = _start_scheduler()
except Exception as _e:
    logger.exception('scheduler start failed: %s', _e)


if __name__ == '__main__':
    port = int(os.environ.get('PORT', 5000))
    host = os.environ.get('HOST', '0.0.0.0')
    use_https = os.environ.get('USE_HTTPS', '0') == '1'
    ssl_context = 'adhoc' if use_https else None
    try:
        if ssl_context:
            socketio.run(app, host=host, port=port, allow_unsafe_werkzeug=True, ssl_context=ssl_context)
        else:
            socketio.run(app, host=host, port=port, allow_unsafe_werkzeug=True)
    finally:
        if scheduler is not None:
            scheduler.shutdown(wait=False)
