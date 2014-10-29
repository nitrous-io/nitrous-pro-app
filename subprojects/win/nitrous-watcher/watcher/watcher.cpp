/* Copyright (c) 2014 Irrational Industries Inc. / Nitrous.IO */

#include "stdafx.h"

void watch_path(const wchar_t *path) {
  std::wcout << _T("Watching path: ") << path << std::endl;
  HANDLE hDirectory = CreateFile(
    (LPCWSTR)path              // lpFileName
  , FILE_LIST_DIRECTORY        // dwDesiredAccess
  , FILE_SHARE_READ | FILE_SHARE_WRITE | FILE_SHARE_DELETE  // dwShareMode
  , NULL                       // lpSecurityAttributes
  , OPEN_EXISTING              // dwCreationDisposition
  , FILE_FLAG_BACKUP_SEMANTICS // dwFlagsAndAttributes
  , NULL                       // hTemplateFile
  );

  FILE_NOTIFY_INFORMATION buffer[256 * sizeof(DWORD)];
  DWORD bytesReturned;

  while (true) {
    BOOL result = ReadDirectoryChangesW(
      hDirectory                 // hDirectory
    , &buffer                    // lpBuffer
    , sizeof(buffer)             // nBufferLength
    , TRUE                       // bWatchSubtree
    , FILE_NOTIFY_CHANGE_FILE_NAME | FILE_NOTIFY_CHANGE_DIR_NAME |
      FILE_NOTIFY_CHANGE_ATTRIBUTES | FILE_NOTIFY_CHANGE_SIZE |
      FILE_NOTIFY_CHANGE_LAST_WRITE // dwNotifyFilter
    , &bytesReturned             // lpBytesReturned
    , NULL                       // lpOverlapped
    , NULL                       // lpCompletionRoutine
    );

    if (!result) {
      return;
    }
    size_t fileNameByteLength = buffer[0].FileNameLength;
    size_t fileNameStringLength = fileNameByteLength + sizeof(wchar_t);
    wchar_t *fileName = (wchar_t *)malloc(fileNameStringLength);
    memset(fileName, 0, fileNameStringLength);
    errno_t err = memcpy_s(fileName, fileNameStringLength, buffer[0].FileName, fileNameByteLength);
    if (err) {
      return;
    }
    std::wcout << _T("Change(") << buffer[0].Action << _T("): ")  << fileName << std::endl;
    free(fileName);
  }
}

int wmain(int argc, wchar_t* argv[]) {
  if (argc != 2) {
    std::wcout << _T("Nitrous Desktop Watcher") << std::endl << "Usage: watcher.exe <path>" << std::endl;
  } else {
    watch_path(argv[1]);
  }
  return 1;
}
