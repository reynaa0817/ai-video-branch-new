package ag_crypto

import "encoding/base64"

var Base64Encryptor = &Base64Encrypt{}

// Base64Encrypt 默认Base64加解密类
type Base64Encrypt struct {
}

// Encrypt 依据base64做字符串的加密处理
func (enc *Base64Encrypt) Encrypt(plaintext string) (string, error) {
	ciphertext := base64.StdEncoding.EncodeToString([]byte(plaintext))
	return ciphertext, nil
}

// Decrypt 将密文转换为明文
func (enc *Base64Encrypt) Decrypt(ciphertext string) (string, error) {
	bytearr, err := base64.StdEncoding.DecodeString(ciphertext)
	return string(bytearr), err
}

// EncrytorName 获取加密方式名字
func (enc *Base64Encrypt) Name() string {
	return "Base64"
}
