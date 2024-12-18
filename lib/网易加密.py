import json
import hashlib
from Crypto.Cipher import AES
from Crypto.Util.Padding import pad

def _aes_encrypt(text, sec_key, algo):
    cipher = AES.new(sec_key.encode('utf-8'), AES.MODE_ECB)
    encrypted = cipher.encrypt(pad(text.encode('utf-8'), AES.block_size))
    return encrypted

def _bytes_to_hex(bytes_data):
    return ''.join([format(byte, '02x') for byte in bytes_data])

def eapi(url, obj):
    eapi_key = 'e82ckenh8dichen8'
    text = json.dumps(obj) if isinstance(obj, dict) else obj
    text = text.replace(' ', '')
    message = f'nobody{url}use{text}md5forencrypt'
    digest = hashlib.md5(message.encode('utf-8')).hexdigest()
    data = f'{url}-36cd479b6b5-{text}-36cd479b6b5-{digest}'
    encrypted = _aes_encrypt(data, eapi_key, 'AES-ECB')
    hex_string = _bytes_to_hex(encrypted).upper()
    return {
        'params': hex_string,
    }

# 示例调用
url = '/api/song/enhance/player/url'
obj = {
    'ids': "[1906277944]",
    'br': 999000,
}
result = eapi(url, obj)
print(result)