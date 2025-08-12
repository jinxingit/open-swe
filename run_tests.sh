#!/bin/bash
set -ex

# Clean up previous test files
rm -f packages/shared/src/__tests__/crypto.test.ts
rm -f packages/shared/src/__tests__/jwt.test.ts
rm -f packages/shared/src/__tests__/git.test.ts

# Create crypto.test.ts
cat <<'EOF' > packages/shared/src/__tests__/crypto.test.ts
import { encryptSecret, decryptSecret } from "../crypto";
describe("Encryption and Decryption", () => {
  const secret = "my-super-secret-token";
  const encryptionKey = "a-strong-encryption-key";
  it("should encrypt and decrypt a secret successfully", () => {
    const encrypted = encryptSecret(secret, encryptionKey);
    const decrypted = decryptSecret(encrypted, encryptionKey);
    expect(decrypted).toBe(secret);
  });
  it("should fail to decrypt with the wrong key", () => {
    const encrypted = encryptSecret(secret, encryptionKey);
    const wrongKey = "wrong-key";
    expect(() => decryptSecret(encrypted, wrongKey)).toThrow(
      /Failed to decrypt secret/,
    );
  });
  it("should throw an error for an empty secret", () => {
    expect(() => encryptSecret("", encryptionKey)).toThrow(
      "Secret must be a non-empty string",
    );
  });
  it("should throw an error for an empty encryption key", () => {
    expect(() => encryptSecret(secret, "")).toThrow(
      "Encryption key must be a non-empty string",
    );
  });
  it("should throw an error for an empty encrypted secret", () => {
    expect(() => decryptSecret("", encryptionKey)).toThrow(
      "Encrypted secret must be a non-empty string",
    );
  });
  it("should throw an error for an empty decryption key", () => {
    const encrypted = encryptSecret(secret, encryptionKey);
    expect(() => decryptSecret(encrypted, "")).toThrow(
      "Encryption key must be a non-empty string",
    );
  });
});
EOF

# Create jwt.test.ts
cat <<'EOF' > packages/shared/src/__tests__/jwt.test.ts
import { generateJWT } from "../jwt";
import jsonwebtoken from "jsonwebtoken";
import * as crypto from "node:crypto";
const { privateKey, publicKey } = crypto.generateKeyPairSync("rsa", {
  modulusLength: 2048,
  publicKeyEncoding: {
    type: "spki",
    format: "pem",
  },
  privateKeyEncoding: {
    type: "pkcs8",
    format: "pem",
  },
});
describe("generateJWT", () => {
  const appId = "12345";
  it("should generate a valid JWT", () => {
    const token = generateJWT(appId, privateKey);
    expect(token).toBeDefined();
    expect(typeof token).toBe("string");
  });
  it("should contain the correct claims", () => {
    const token = generateJWT(appId, privateKey);
    const decoded = jsonwebtoken.verify(token, publicKey, {
      algorithms: ["RS256"],
    });
    expect(typeof decoded).toBe("object");
    if (typeof decoded === "object" && decoded !== null) {
      expect(decoded.iss).toBe(appId);
      expect(decoded.iat).toBeDefined();
      expect(decoded.exp).toBeDefined();
      expect(decoded.exp - decoded.iat).toBeCloseTo(600, 0);
    }
  });
});
EOF

# Create git.test.ts
cat <<'EOF' > packages/shared/src/__tests__/git.test.ts
import { getRepoAbsolutePath } from "../git";
import { SANDBOX_ROOT_DIR } from "../constants";
import { getLocalWorkingDirectory } from "../open-swe/local-mode";
import { GraphConfig, TargetRepository } from "../open-swe/types";
jest.mock("../open-swe/local-mode", () => ({
  ...jest.requireActual("../open-swe/local-mode"),
  isLocalMode: jest.fn(),
  getLocalWorkingDirectory: jest.fn(),
}));
describe("getRepoAbsolutePath", () => {
  const targetRepository: TargetRepository = {
    owner: "test-owner",
    repo: "test-repo",
  };
  beforeEach(() => {
    (require("../open-swe/local-mode").isLocalMode as jest.Mock).mockClear();
    (
      require("../open-swe/local-mode").getLocalWorkingDirectory as jest.Mock
    ).mockClear();
  });
  it("should return the standard repository path when not in local mode", () => {
    const result = getRepoAbsolutePath(targetRepository);
    expect(result).toBe(`${SANDBOX_ROOT_DIR}/${targetRepository.repo}`);
  });
  it("should return the local working directory when in local mode", () => {
    const mockLocalPath = "/path/to/local/repo";
    const config: GraphConfig = {
      llm: {
        model: "test-model",
      },
      local: {
        enabled: true,
        path: mockLocalPath,
      },
    };
    (require("../open-swe/local-mode").isLocalMode as jest.Mock).mockReturnValue(
      true,
    );
    (
      require("../open-swe/local-mode").getLocalWorkingDirectory as jest.Mock
    ).mockReturnValue(mockLocalPath);
    const result = getRepoAbsolutePath(targetRepository, config);
    expect(result).toBe(mockLocalPath);
  });
  it("should throw an error if no repository name is provided and not in local mode", () => {
    const invalidRepo: TargetRepository = {
      owner: "test-owner",
      repo: "",
    };
    expect(() => getRepoAbsolutePath(invalidRepo)).toThrow(
      "No repository name provided",
    );
  });
});
EOF

# Verify that the files have been created
ls -l packages/shared/src/__tests__/

# Run the tests
yarn test
