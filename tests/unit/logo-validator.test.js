/**
 * Unit tests for logo-validator.js
 */

const { expect } = require('chai');
const fs = require('fs');
const path = require('path');
const os = require('os');
const {
  validateLogo,
  findLogoFile,
  validateMagicBytes,
  getLogoInfo,
  ALLOWED_EXTENSIONS,
  LOGO_SIZE_WARNING,
  LOGO_SIZE_ERROR,
} = require('../../scripts/validators/logo-validator');

describe('Logo Validator', () => {
  // Create temp directory for test files
  let tempDir;
  const testAddress = '0x00c1E515EA9579856304198EFb15f525A0bb50f6';

  beforeEach(() => {
    tempDir = fs.mkdtempSync(path.join(os.tmpdir(), 'logo-test-'));
  });

  afterEach(() => {
    // Clean up temp directory
    if (fs.existsSync(tempDir)) {
      fs.rmSync(tempDir, { recursive: true, force: true });
    }
  });

  // Helper to create a valid PNG file (minimal valid PNG)
  function createValidPNG(filePath, sizeKB = 1) {
    // PNG magic bytes followed by padding to reach desired size
    const pngHeader = Buffer.from([
      0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a, // PNG signature
      0x00, 0x00, 0x00, 0x0d, // IHDR length
      0x49, 0x48, 0x44, 0x52, // IHDR
    ]);
    const padding = Buffer.alloc(Math.max(0, sizeKB * 1024 - pngHeader.length));
    fs.writeFileSync(filePath, Buffer.concat([pngHeader, padding]));
  }

  // Helper to create a valid JPEG file
  function createValidJPEG(filePath, sizeKB = 1) {
    // JPEG magic bytes followed by padding
    const jpegHeader = Buffer.from([0xff, 0xd8, 0xff, 0xe0]);
    const padding = Buffer.alloc(Math.max(0, sizeKB * 1024 - jpegHeader.length));
    fs.writeFileSync(filePath, Buffer.concat([jpegHeader, padding]));
  }

  // Helper to create a valid WebP file
  function createValidWebP(filePath, sizeKB = 1) {
    // WebP header: RIFF + size + WEBP
    const webpHeader = Buffer.from([
      0x52, 0x49, 0x46, 0x46, // RIFF
      0x00, 0x00, 0x00, 0x00, // Size placeholder
      0x57, 0x45, 0x42, 0x50, // WEBP
    ]);
    const padding = Buffer.alloc(Math.max(0, sizeKB * 1024 - webpHeader.length));
    fs.writeFileSync(filePath, Buffer.concat([webpHeader, padding]));
  }

  describe('findLogoFile', () => {
    it('should find PNG logo file', () => {
      const logoPath = path.join(tempDir, `${testAddress}.png`);
      createValidPNG(logoPath);

      const result = findLogoFile(tempDir, testAddress);
      expect(result.found).to.be.true;
      expect(result.extension).to.equal('.png');
      expect(result.path).to.equal(logoPath);
    });

    it('should find JPG logo file', () => {
      const logoPath = path.join(tempDir, `${testAddress}.jpg`);
      createValidJPEG(logoPath);

      const result = findLogoFile(tempDir, testAddress);
      expect(result.found).to.be.true;
      expect(result.extension).to.equal('.jpg');
    });

    it('should find JPEG logo file', () => {
      const logoPath = path.join(tempDir, `${testAddress}.jpeg`);
      createValidJPEG(logoPath);

      const result = findLogoFile(tempDir, testAddress);
      expect(result.found).to.be.true;
      expect(result.extension).to.equal('.jpeg');
    });

    it('should find WebP logo file', () => {
      const logoPath = path.join(tempDir, `${testAddress}.webp`);
      createValidWebP(logoPath);

      const result = findLogoFile(tempDir, testAddress);
      expect(result.found).to.be.true;
      expect(result.extension).to.equal('.webp');
    });

    it('should return found=false when no logo exists', () => {
      const result = findLogoFile(tempDir, testAddress);
      expect(result.found).to.be.false;
    });

    it('should prefer PNG over other formats when multiple exist', () => {
      // PNG is first in ALLOWED_EXTENSIONS, so it should be found first
      createValidPNG(path.join(tempDir, `${testAddress}.png`));
      createValidJPEG(path.join(tempDir, `${testAddress}.jpg`));

      const result = findLogoFile(tempDir, testAddress);
      expect(result.found).to.be.true;
      expect(result.extension).to.equal('.png');
    });
  });

  describe('validateMagicBytes', () => {
    it('should validate PNG magic bytes with .png extension', () => {
      const pngBuffer = Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a, 0x00, 0x00, 0x00, 0x00]);
      const result = validateMagicBytes(pngBuffer, '.png');
      expect(result.valid).to.be.true;
      expect(result.detectedFormat).to.equal('png');
    });

    it('should reject PNG content with wrong extension', () => {
      const pngBuffer = Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a, 0x00, 0x00, 0x00, 0x00]);
      const result = validateMagicBytes(pngBuffer, '.jpg');
      expect(result.valid).to.be.false;
      expect(result.detectedFormat).to.equal('png');
      expect(result.error).to.include('PNG');
    });

    it('should validate JPEG magic bytes with .jpg extension', () => {
      const jpegBuffer = Buffer.from([0xff, 0xd8, 0xff, 0xe0, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00]);
      const result = validateMagicBytes(jpegBuffer, '.jpg');
      expect(result.valid).to.be.true;
      expect(result.detectedFormat).to.equal('jpg');
    });

    it('should validate JPEG magic bytes with .jpeg extension', () => {
      const jpegBuffer = Buffer.from([0xff, 0xd8, 0xff, 0xe0, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00]);
      const result = validateMagicBytes(jpegBuffer, '.jpeg');
      expect(result.valid).to.be.true;
      expect(result.detectedFormat).to.equal('jpg');
    });

    it('should validate WebP magic bytes', () => {
      const webpBuffer = Buffer.from([
        0x52, 0x49, 0x46, 0x46, // RIFF
        0x00, 0x00, 0x00, 0x00, // Size
        0x57, 0x45, 0x42, 0x50, // WEBP
      ]);
      const result = validateMagicBytes(webpBuffer, '.webp');
      expect(result.valid).to.be.true;
      expect(result.detectedFormat).to.equal('webp');
    });

    it('should reject unrecognized format', () => {
      const randomBuffer = Buffer.from([0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00]);
      const result = validateMagicBytes(randomBuffer, '.png');
      expect(result.valid).to.be.false;
      expect(result.error).to.include('Unrecognized');
    });
  });

  describe('validateLogo', () => {
    it('should pass for valid PNG logo', () => {
      const logoPath = path.join(tempDir, `${testAddress}.png`);
      createValidPNG(logoPath, 50); // 50KB

      const result = validateLogo(tempDir, testAddress, 'TEST');
      expect(result.valid).to.be.true;
    });

    it('should fail when logo file is missing', () => {
      const result = validateLogo(tempDir, testAddress, 'TEST');
      expect(result.valid).to.be.false;
      expect(result.error).to.include('Missing required logo file');
      expect(result.error).to.include('TEST');
    });

    it('should fail when logo file exceeds 500KB', () => {
      const logoPath = path.join(tempDir, `${testAddress}.png`);
      createValidPNG(logoPath, 600); // 600KB - over limit

      const result = validateLogo(tempDir, testAddress, 'TEST');
      expect(result.valid).to.be.false;
      expect(result.error).to.include('too large');
    });

    it('should warn when logo file exceeds 100KB', () => {
      const logoPath = path.join(tempDir, `${testAddress}.png`);
      createValidPNG(logoPath, 150); // 150KB - over warning threshold

      const result = validateLogo(tempDir, testAddress, 'TEST');
      expect(result.valid).to.be.true;
      expect(result.warnings).to.exist;
      expect(result.warnings[0]).to.include('large');
    });

    it('should fail when file content does not match extension', () => {
      const logoPath = path.join(tempDir, `${testAddress}.png`);
      // Write JPEG content but with .png extension
      createValidJPEG(logoPath, 10);

      const result = validateLogo(tempDir, testAddress, 'TEST');
      expect(result.valid).to.be.false;
      expect(result.error).to.include('JPEG');
    });

    it('should pass for valid JPEG logo', () => {
      const logoPath = path.join(tempDir, `${testAddress}.jpg`);
      createValidJPEG(logoPath, 50);

      const result = validateLogo(tempDir, testAddress, 'TEST');
      expect(result.valid).to.be.true;
    });

    it('should pass for valid WebP logo', () => {
      const logoPath = path.join(tempDir, `${testAddress}.webp`);
      createValidWebP(logoPath, 50);

      const result = validateLogo(tempDir, testAddress, 'TEST');
      expect(result.valid).to.be.true;
    });
  });

  describe('getLogoInfo', () => {
    it('should return info for existing logo', () => {
      const logoPath = path.join(tempDir, `${testAddress}.png`);
      createValidPNG(logoPath, 25);

      const info = getLogoInfo(tempDir, testAddress);
      expect(info.exists).to.be.true;
      expect(info.path).to.equal(logoPath);
      expect(info.format).to.equal('png');
      expect(info.size).to.be.greaterThan(0);
    });

    it('should return exists=false for missing logo', () => {
      const info = getLogoInfo(tempDir, testAddress);
      expect(info.exists).to.be.false;
    });
  });

  describe('Constants', () => {
    it('should export allowed extensions', () => {
      expect(ALLOWED_EXTENSIONS).to.include('.png');
      expect(ALLOWED_EXTENSIONS).to.include('.jpg');
      expect(ALLOWED_EXTENSIONS).to.include('.webp');
    });

    it('should export size limits', () => {
      expect(LOGO_SIZE_WARNING).to.equal(100 * 1024);
      expect(LOGO_SIZE_ERROR).to.equal(500 * 1024);
    });
  });
});
