// ShortNameHelper.cpp : Defines the entry point for the console application.
//

#include "stdafx.h"


int wmain(int argc, wchar_t* argv[]) {
	if (argc == 0) {
		std::wcout << _T("Nitrous Short name helper") << std::endl << "Usage: shortname.exe <path>" << std::endl;
		return 1;
	}

	std::wstring all;
	for (int n = 1; n < argc; n++) {
		if (n != 1)
			all += L" ";
		all += argv[n];
	}

	long     length = 0;
	TCHAR*   buffer = NULL;
	length = GetShortPathName(all.c_str(), NULL, 0);
	if (length == 0) {
		std::wcerr << _T("Unable to resolve path") << std::endl;
		std::wcerr << all << std::endl;
		return 1;
	}

	buffer = new TCHAR[length];
	length = GetShortPathName(all.c_str(), buffer, length);
	if (length == 0) {
		std::wcerr << _T("Unable to resolve path") << std::endl;
		std::wcerr << all << std::endl;
		return 1;
	}

	std::wcout << buffer << std::endl;

	delete [] buffer;
	return 0;
}

