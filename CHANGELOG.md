# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.1.0] - 2026-01-03

### Added

#### Logo File Requirement
- **BREAKING:** Token submissions now require a logo file (`{address}.png/jpg/webp`)
- New `logo-validator.js` module validates:
  - Logo file existence (required)
  - File size limits (warning >100KB, error >500KB)
  - Magic byte validation (file content matches extension)
- 23 new unit tests for logo validation
- Downloaded logos for all 7 existing tokens from their `logoURI` URLs

#### Documentation Updates
- Updated README.md with logo requirements and specifications
- Updated token submission issue template (logo now required)
- Updated `tokens/EXAMPLE.md` with logo file documentation
- Updated token schema description to note logo requirement

### Changed
- Token validation now checks for logo file before validating other fields
- `logoURI` field is now optional (physical logo file is required instead)

## [1.0.0] - 2025-11-23

### Added

#### Tokens Registry
- 7 initial tokens migrated from tokens-list
  - VINU (Vita Inu)
  - WVC (Wrapped VC)
  - USDT@VinuChain
  - ETH@VinuChain
  - VIN (VINUHUB)
  - BTC@VinuChain
  - VIR (VinuRepublic)
- Token schema with optional "project" field for cross-referencing
- Address-based folder structure: `tokens/{address}/{address}.json`

#### Contracts Registry
- VinuSwap example project with 6 contracts
  - Controller, Factory, Router, PositionDescriptor, PositionManager, Quoter
- Project-based folder structure: `contracts/{project-slug}/`
- Contract metadata in `info.json`
- Source code files (`.sol`)
- ABI files (`_abi.json`)
- Contract schema for project validation

#### Validation
- Unified validation script for both tokens and contracts
- EIP-55 checksum validation
- Schema validation with AJV
- Cross-reference validation (tokens ↔ projects)
- Duplicate address detection
- Contract file existence verification
- ABI format validation

#### Automation
- GitHub Actions workflow for automated validation
- PR comment automation
- JSON format checking

#### Documentation
- Comprehensive README.md
- Issue templates:
  - Token submission form
  - Contract project submission form
  - Bug report template
- CODE_OF_CONDUCT.md
- LICENSE (MIT)
- CHANGELOG.md

### Changed
- Merged tokens-list and contracts-list into unified vinuchain-lists repository
- Removed chain ID prefix from contract structure (VinuChain only)
- Simplified directory structure for better organization

### Security
- EIP-55 checksum validation for all addresses
- HTTPS-only URL validation
- Input validation through JSON schemas
- Maximum string length constraints to prevent DoS
- Symbol format validation (uppercase alphanumeric)

[1.0.0]: https://github.com/VinuChain/vinuchain-lists/releases/tag/v1.0.0
