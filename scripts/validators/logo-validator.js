/**
 * Logo file validation utilities
 * Validates that each token has a required logo file matching the token address
 */

const fs = require('fs');
const path = require('path');

// Logo file size limits
const LOGO_SIZE_WARNING = 100 * 1024; // 100KB - warn
const LOGO_SIZE_ERROR = 500 * 1024;   // 500KB - error

// Allowed logo extensions
const ALLOWED_EXTENSIONS = ['.png', '.jpg', '.jpeg', '.webp'];

// Magic bytes for image format validation
const MAGIC_BYTES = {
  png: Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]),
  jpg: Buffer.from([0xff, 0xd8, 0xff]),
  webp: Buffer.from([0x52, 0x49, 0x46, 0x46]), // RIFF header (WebP starts with RIFF)
};

/**
 * Find logo file in token directory
 * @param {string} tokenDir - Path to token directory
 * @param {string} address - Token address (EIP-55 checksummed)
 * @returns {{found: boolean, path?: string, extension?: string}} Search result
 */
function findLogoFile(tokenDir, address) {
  for (const ext of ALLOWED_EXTENSIONS) {
    const logoPath = path.join(tokenDir, `${address}${ext}`);
    if (fs.existsSync(logoPath)) {
      return { found: true, path: logoPath, extension: ext };
    }
  }
  return { found: false };
}

/**
 * Validate magic bytes match the file extension
 * @param {Buffer} buffer - File buffer (first 12 bytes minimum)
 * @param {string} extension - File extension (.png, .jpg, .webp)
 * @returns {{valid: boolean, detectedFormat?: string, error?: string}} Validation result
 */
function validateMagicBytes(buffer, extension) {
  const ext = extension.toLowerCase();

  // Check PNG
  if (buffer.slice(0, 8).equals(MAGIC_BYTES.png)) {
    if (ext === '.png') {
      return { valid: true, detectedFormat: 'png' };
    }
    return {
      valid: false,
      detectedFormat: 'png',
      error: `File is PNG but has ${ext} extension`,
    };
  }

  // Check JPEG
  if (buffer.slice(0, 3).equals(MAGIC_BYTES.jpg)) {
    if (ext === '.jpg' || ext === '.jpeg') {
      return { valid: true, detectedFormat: 'jpg' };
    }
    return {
      valid: false,
      detectedFormat: 'jpg',
      error: `File is JPEG but has ${ext} extension`,
    };
  }

  // Check WebP (RIFF header + WEBP at offset 8)
  if (buffer.slice(0, 4).equals(MAGIC_BYTES.webp)) {
    const webpSignature = buffer.slice(8, 12).toString('ascii');
    if (webpSignature === 'WEBP') {
      if (ext === '.webp') {
        return { valid: true, detectedFormat: 'webp' };
      }
      return {
        valid: false,
        detectedFormat: 'webp',
        error: `File is WebP but has ${ext} extension`,
      };
    }
  }

  return {
    valid: false,
    error: `Unrecognized image format for ${ext} file`,
  };
}

/**
 * Validate logo file for a token
 * @param {string} tokenDir - Path to token directory
 * @param {string} address - Token address (EIP-55 checksummed)
 * @param {string} symbol - Token symbol (for error messages)
 * @returns {{valid: boolean, error?: string, warnings?: string[]}} Validation result
 */
function validateLogo(tokenDir, address, symbol) {
  const warnings = [];

  // Find logo file
  const logoSearch = findLogoFile(tokenDir, address);
  if (!logoSearch.found) {
    const expectedFiles = ALLOWED_EXTENSIONS.map(ext => `${address}${ext}`).join(', ');
    return {
      valid: false,
      error: `${symbol}: Missing required logo file. Expected one of: ${expectedFiles}`,
    };
  }

  const logoPath = logoSearch.path;
  const extension = logoSearch.extension;

  // Get file stats
  let stats;
  try {
    stats = fs.statSync(logoPath);
  } catch (e) {
    return {
      valid: false,
      error: `${symbol}: Cannot read logo file: ${e.message}`,
    };
  }

  // Check file size
  if (stats.size > LOGO_SIZE_ERROR) {
    return {
      valid: false,
      error: `${symbol}: Logo file too large (${(stats.size / 1024).toFixed(1)}KB). Maximum: ${LOGO_SIZE_ERROR / 1024}KB`,
    };
  }

  if (stats.size > LOGO_SIZE_WARNING) {
    warnings.push(
      `${symbol}: Logo file is large (${(stats.size / 1024).toFixed(1)}KB). Recommended: <${LOGO_SIZE_WARNING / 1024}KB`
    );
  }

  // Read file header for magic byte validation
  let buffer;
  try {
    const fd = fs.openSync(logoPath, 'r');
    buffer = Buffer.alloc(12);
    fs.readSync(fd, buffer, 0, 12, 0);
    fs.closeSync(fd);
  } catch (e) {
    return {
      valid: false,
      error: `${symbol}: Cannot read logo file header: ${e.message}`,
    };
  }

  // Validate magic bytes
  const magicValidation = validateMagicBytes(buffer, extension);
  if (!magicValidation.valid) {
    return {
      valid: false,
      error: `${symbol}: ${magicValidation.error}`,
    };
  }

  return { valid: true, warnings: warnings.length > 0 ? warnings : undefined };
}

/**
 * Get logo file info for a token (utility function)
 * @param {string} tokenDir - Path to token directory
 * @param {string} address - Token address
 * @returns {{exists: boolean, path?: string, size?: number, format?: string}} Logo info
 */
function getLogoInfo(tokenDir, address) {
  const logoSearch = findLogoFile(tokenDir, address);
  if (!logoSearch.found) {
    return { exists: false };
  }

  try {
    const stats = fs.statSync(logoSearch.path);
    return {
      exists: true,
      path: logoSearch.path,
      size: stats.size,
      format: logoSearch.extension.slice(1), // Remove leading dot
    };
  } catch {
    return { exists: false };
  }
}

module.exports = {
  validateLogo,
  findLogoFile,
  validateMagicBytes,
  getLogoInfo,
  ALLOWED_EXTENSIONS,
  LOGO_SIZE_WARNING,
  LOGO_SIZE_ERROR,
};
