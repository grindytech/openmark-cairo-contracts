module.exports = {
    preset: 'ts-jest',
    testEnvironment: 'node',
    testMatch: ['<rootDir>/src/tests/staging/**/*.test.ts'],
    testTimeout: 200000, // 3.5 minutes in milliseconds
};
