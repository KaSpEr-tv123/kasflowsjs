module.exports = {
  // Указываем Jest игнорировать файлы ручного тестирования
  testPathIgnorePatterns: [
    '/node_modules/',
    '/tests/client.test.js',
    '/tests/server.test.js'
  ],
  // Устанавливаем таймаут для тестов
  testTimeout: 10000,
  // Очищаем моки после каждого теста
  clearMocks: true,
  // Указываем Jest завершаться после выполнения тестов
  forceExit: true
}; 