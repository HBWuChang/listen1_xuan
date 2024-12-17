# {"csrf_token":"af3c2b3649aac37f7dd3a32ce1818ffc"}
import random
import base64
from Crypto.Cipher import AES
from Crypto.Util.Padding import pad
from Crypto.PublicKey import RSA
from Crypto.Util.number import bytes_to_long, long_to_bytes
import json
def _create_secret_key(size):
    return '1234567890123456'
    choice = '012345679abcdef'
    return ''.join(random.choice(choice) for _ in range(size))

def _aes_encrypt(text, sec_key, algo):
    cipher = AES.new(sec_key.encode('utf-8'), AES.MODE_CBC, iv='0102030405060708'.encode('utf-8'))
    print("text=",text)
    print(AES.block_size)
    t=pad(text.encode('utf-8'), AES.block_size)
    print("t=",t)
    for i in t:
        print(int(i),end=',')
    print()
    encrypted = cipher.encrypt(t)
    print("encrypted=")
    for i in encrypted:
        print(int(i),end=',')
    print()
    return encrypted

def _rsa_encrypt(text, pubKey, modulus):
    text = text[::-1]
    n = int(modulus, 16)
    e = int(pubKey, 16)
    b = bytes_to_long(text.encode('utf-8'))
    enc = pow(b, e, n)
    return format(enc, 'x').zfill(256)

def weapi(text):
    modulus = (
        '00e0b509f6259df8642dbc35662901477df22677ec152b5ff68ace615bb7b72'
        '5152b3ab17a876aea8a5aa76d2e417629ec4ee341f56135fccf695280104e0312ecbd'
        'a92557c93870114af6c9d05c4f7f0c3685b7a46bee255932575cce10b424d813cfe48'
        '75d3e82047b97ddef52741d546b8e289dc6935b3ece0462db0a22b8e7'
    )
    nonce = '0CoJUm6Qyw8W8jud'
    pubKey = '010001'
    text = json.dumps(text).replace(' ', '')
    print(text)
    sec_key = _create_secret_key(16)
    t1=_aes_encrypt(text, nonce, 'AES-CBC')
    print(t1)
    t2=base64.b64encode(t1).decode('utf-8')
    print(t2)
    t3=_aes_encrypt(t2, sec_key, 'AES-CBC')
    t4=base64.b64encode(t3).decode('utf-8')
    print(t4)
    enc_text = t4
    # enc_text = base64.b64encode(
    #     _aes_encrypt(
    #         base64.b64encode(_aes_encrypt(text, nonce, 'AES-CBC')).decode('utf-8'),
    #         sec_key,
    #         'AES-CBC'
    #     )
    # ).decode('utf-8')
    enc_sec_key = _rsa_encrypt(sec_key, pubKey, modulus)
    data = {
        'params': enc_text,
        'encSecKey': enc_sec_key,
    }
    return data

# def weapi(text):
#     modulus = (
#         '00e0b509f6259df8642dbc35662901477df22677ec152b5ff68ace615bb7b72'
#         '5152b3ab17a876aea8a5aa76d2e417629ec4ee341f56135fccf695280104e0312ecbd'
#         'a92557c93870114af6c9d05c4f7f0c3685b7a46bee255932575cce10b424d813cfe48'
#         '75d3e82047b97ddef52741d546b8e289dc6935b3ece0462db0a22b8e7'
#     )
#     nonce = '0CoJUm6Qyw8W8jud'
#     pubKey = '010001'
#     text = json.dumps(text).replace(' ', '')
#     print(text)
#     sec_key = _create_secret_key(16)
#     enc_text = base64.b64encode(
#         _aes_encrypt(
#             base64.b64encode(_aes_encrypt(text, nonce, 'AES-CBC')).decode('utf-8'),
#             sec_key,
#             'AES-CBC'
#         )
#     ).decode('utf-8')
#     enc_sec_key = _rsa_encrypt(sec_key, pubKey, modulus)
#     data = {
#         'params': enc_text,
#         'encSecKey': enc_sec_key,
#     }
#     return data

if __name__ == '__main__':
    text ={"csrf_token":"af3c2b3649aac37f7dd3a32ce1818ffc"}
    t=weapi(text)
    for i in t:
        print(i+'='+t[i]+'&',end='')