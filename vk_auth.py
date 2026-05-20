import os
from functools import wraps
from urllib.parse import urlencode
import requests
from flask import session, redirect, jsonify, request


VK_AUTHORIZE_URL = 'https://oauth.vk.com/authorize'
VK_TOKEN_URL = 'https://oauth.vk.com/access_token'
VK_USERS_GET_URL = 'https://api.vk.com/method/users.get'
VK_API_VERSION = '5.131'


class VKAuthError(Exception):
    pass


def build_authorize_url():
    params = {
        'client_id': os.environ.get('VK_CLIENT_ID', ''),
        'redirect_uri': os.environ.get('VK_REDIRECT_URI', ''),
        'response_type': 'code',
        'scope': 'wall,offline,email',
        'v': VK_API_VERSION,
    }
    return '{}?{}'.format(VK_AUTHORIZE_URL, urlencode(params))


def exchange_code(code):
    params = {
        'client_id': os.environ.get('VK_CLIENT_ID', ''),
        'client_secret': os.environ.get('VK_CLIENT_SECRET', ''),
        'redirect_uri': os.environ.get('VK_REDIRECT_URI', ''),
        'code': code,
    }
    try:
        response = requests.get(VK_TOKEN_URL, params=params, timeout=10)
    except requests.RequestException as exc:
        raise VKAuthError('token_exchange_network_error: {}'.format(exc)) from exc
    try:
        payload = response.json()
    except ValueError as exc:
        raise VKAuthError('token_exchange_invalid_json: {}'.format(exc)) from exc
    if response.status_code != 200 or 'access_token' not in payload:
        raise VKAuthError(payload.get('error_description') or payload.get('error') or 'token_exchange_failed')
    return {
        'access_token': payload['access_token'],
        'user_id': int(payload['user_id']),
        'email': payload.get('email'),
        'expires_in': int(payload.get('expires_in', 0)),
    }


def get_profile(token, vk_user_id):
    params = {
        'user_ids': vk_user_id,
        'fields': 'country,city,screen_name,first_name,last_name',
        'access_token': token,
        'v': VK_API_VERSION,
    }
    try:
        response = requests.get(VK_USERS_GET_URL, params=params, timeout=10)
    except requests.RequestException as exc:
        raise VKAuthError('profile_network_error: {}'.format(exc)) from exc
    try:
        payload = response.json()
    except ValueError as exc:
        raise VKAuthError('profile_invalid_json: {}'.format(exc)) from exc
    if 'response' not in payload or not payload['response']:
        raise VKAuthError(payload.get('error', {}).get('error_msg', 'profile_fetch_failed'))
    user = payload['response'][0]
    country = (user.get('country') or {}).get('id')
    screen_name = user.get('screen_name') or user.get('first_name') or 'vk_user_{}'.format(vk_user_id)
    return {
        'vk_id': int(user['id']),
        'username': screen_name,
        'country_id': country,
        'first_name': user.get('first_name'),
        'last_name': user.get('last_name'),
    }


def country_from_vk(country_id):
    if country_id == 1:
        return 'RU'
    if country_id == 4:
        return 'AM'
    return 'OTHER'


def _wants_json():
    if request.path.startswith('/api/') or request.path.startswith('/webhook/'):
        return True
    accept = request.headers.get('Accept', '')
    return 'application/json' in accept


def login_required(view):
    @wraps(view)
    def wrapper(*args, **kwargs):
        if 'user_id' not in session:
            if _wants_json():
                return jsonify({'error': 'unauthorized'}), 401
            return redirect('/auth/vk')
        return view(*args, **kwargs)
    return wrapper


def current_user_id():
    return session.get('user_id')
