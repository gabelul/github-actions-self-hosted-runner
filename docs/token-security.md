# GitHub Token Security Guide

This guide explains how the GitHub Self-Hosted Runner tool securely stores your GitHub personal access tokens using encryption.

## 🔐 How Token Encryption Works

Our tool uses **pure bash XOR encryption** with salt protection to securely store your GitHub tokens. This approach was chosen because:

- **Universal compatibility**: Works on any system with bash (Linux, macOS, Windows Git Bash)
- **No dependencies**: Doesn't require OpenSSL, GPG, or any external tools
- **Reasonable security**: Sufficient protection for GitHub tokens
- **Easy maintenance**: Pure bash implementation, no complex dependencies

### Encryption Technical Details

1. **XOR Cipher with Salt**: Your token is encrypted using XOR cipher with a timestamp-based salt
2. **Password Protection**: You create a password that's used to generate the encryption key
3. **Hash Verification**: Password hash is stored separately to verify authentication
4. **Base64 Encoding**: Encrypted data is base64-encoded for safe file storage

```bash
# Encryption process
salt=$(date +%s)                    # Timestamp salt
key="${password}${salt}"            # Salted password
encrypted=$(xor_encrypt "$token" "$key")  # XOR encryption
base64_data=$(echo "$encrypted" | base64) # Safe encoding
```

## 🛡️ Security Features

### File Security
- **Location**: `~/.github-runner/config/` (user home directory)
- **Permissions**: 600 (only owner can read/write)
- **Separation**: Token and password hash stored in separate files
- **No plaintext**: Token is never stored in plaintext

### Encryption Security
- **Salt protection**: Each encryption uses a unique timestamp salt
- **Password verification**: Hash verification prevents incorrect passwords
- **No password storage**: Only password hash stored, never the actual password
- **Auto-cleanup**: Failed decryption attempts don't leave traces

## 📁 Storage Locations

```
~/.github-runner/config/
├── .token.enc     # Encrypted token (base64 encoded)
└── .auth          # Password hash for verification
```

**Important**: These files are automatically created with 600 permissions (only you can access them).

## 🚀 Using Token Encryption

### Interactive Mode

When you run `./setup.sh`, the wizard will:

1. **Check for saved token** at startup
2. **Offer to use saved token** if found
3. **Prompt for password** to decrypt
4. **Ask to save new tokens** after successful authentication

```bash
# First time setup
./setup.sh
# → Enter GitHub token
# → "Save this token securely for future use? [Y/n]"
# → Create password
# → Token encrypted and saved

# Next time
./setup.sh
# → "Found saved encrypted token. Use it? [Y/n]"
# → Enter password
# → Token decrypted and used automatically
```

### Command Line Management

```bash
# Remove saved token
./setup.sh --clear-token

# Display saved token (requires password)
./setup.sh --show-token

# Normal setup with token auto-detection
./setup.sh
```

### Direct Mode (Skip Interactive)

```bash
# Use saved token in direct mode
./setup.sh --repo owner/project --docker
# → Automatically loads saved token if available
```

## 🔒 Password Best Practices

### Creating Strong Passwords

1. **Use a memorable phrase**: "MyGitHubRunner2024!"
2. **Include mixed case and numbers**: Upper, lower, digits
3. **Avoid common passwords**: Don't use "password123"
4. **Make it unique**: Don't reuse other passwords

### Password Recovery

**Important**: There is **NO password recovery mechanism** by design. If you forget your password:

1. The encrypted token cannot be recovered
2. You'll need to create a new GitHub token
3. Clear the old encrypted token: `./setup.sh --clear-token`
4. Run setup again to save the new token

This design choice ensures maximum security - even if someone gets access to your encrypted files, they can't recover your token without the password.

## 🛠️ Troubleshooting

### "Failed to decrypt token"

**Cause**: Incorrect password or corrupted encryption file.

**Solutions**:
```bash
# Try again with correct password
./setup.sh

# If password is definitely correct, clear and recreate
./setup.sh --clear-token
./setup.sh  # Setup fresh
```

### "Invalid password"

**Cause**: Password doesn't match the one used during encryption.

**Solution**: Enter the correct password, or clear token if forgotten:
```bash
./setup.sh --clear-token
```

### Corrupted Encryption Files

**Symptoms**: Errors during decryption, garbled output.

**Solution**: Clear and recreate the token:
```bash
./setup.sh --clear-token
./setup.sh  # Fresh setup
```

### Permission Denied

**Cause**: Incorrect file permissions on encryption files.

**Solution**: Fix permissions or recreate:
```bash
# Fix permissions
chmod 600 ~/.github-runner/config/.token.enc
chmod 600 ~/.github-runner/config/.auth

# Or recreate entirely
./setup.sh --clear-token
./setup.sh
```

## 🔍 Security Considerations

### What This Protects Against

✅ **Casual file browsing**: Token isn't visible in plaintext
✅ **Accidental exposure**: Encrypted files are safe to see
✅ **Basic attacks**: XOR with salt provides reasonable protection
✅ **File theft**: Useless without password

### What This Doesn't Protect Against

❌ **Advanced cryptanalysis**: XOR is not military-grade encryption
❌ **Password compromise**: If password is stolen, token can be decrypted
❌ **System compromise**: If attacker has full system access, they can potentially extract tokens
❌ **Keyloggers**: Password entry could be captured

### Recommendations for High-Security Environments

For environments requiring maximum security:

1. **Use short-lived tokens**: Regenerate GitHub tokens frequently
2. **Limit token scope**: Only grant minimum required permissions
3. **Monitor token usage**: Check GitHub token usage logs regularly
4. **Consider external encryption**: Use GPG or similar for additional protection
5. **Secure the host**: Ensure the host system is properly secured

## 🔄 Token Lifecycle Management

### Regular Token Rotation

Good security practice includes regular token rotation:

```bash
# 1. Generate new GitHub token
# 2. Clear old encrypted token
./setup.sh --clear-token

# 3. Run setup with new token
./setup.sh
# → Enter new token
# → Save with new password
```

### Backup and Recovery

**Important**: You cannot backup encrypted tokens between systems because:
- Each encryption includes timestamp-based salt
- Passwords are hashed with system-specific data

**Best practice**: Keep your GitHub token generation method documented so you can recreate tokens when needed.

## 🆘 Getting Help

If you encounter issues with token encryption:

1. **Check the logs**: Run with `--verbose` for detailed output
2. **Try manual token entry**: Use setup without saved token
3. **Clear and recreate**: `./setup.sh --clear-token` then fresh setup
4. **Check permissions**: Ensure proper file permissions on config directory

For additional help, see:
- [Troubleshooting Guide](troubleshooting.md)
- [GitHub Issues](https://github.com/gabelul/github-self-hosted-runner/issues)

Remember: Token encryption is about convenience and basic security. The most important security practice is keeping your GitHub tokens secure and rotating them regularly.