#include <iostream>
#include <memory>
#include <filesystem>
#include <Windows.h>
#include <iomanip>
#include <vector>
#include <string>

#include "Dithering.h"
#include "BMP.hpp"
#include "Colors.h"

int main()
{
	_CrtSetDbgFlag(_CRTDBG_ALLOC_MEM_DF | _CRTDBG_LEAK_CHECK_DF);

	typedef uint64_t(*Myproc)(const uint32_t&, unsigned char*, uint32_t&, const uint32_t&, const uint32_t&, unsigned char*, uint32_t&, unsigned char*, double*);

	//LPCSTR name = "JADll.dll";
	HMODULE library = LoadLibraryA("JADll.dll");
	if (library == NULL) {
		printf("Nie uda³o siê za³adowaæ DLL.\n");
		return -1;
	}

	Myproc Procedure = (Myproc)GetProcAddress(library, "JohnSteinberg");

	BMP photo, ditherPhoto;
	Colors color;
	std::string ditherFileName = "testBig";

	std::filesystem::path iterColorDirPath = std::filesystem::current_path();
	std::filesystem::path iterCopy = std::filesystem::current_path();
	std::filesystem::path iterSave = std::filesystem::current_path();
	std::filesystem::path iterCsv = std::filesystem::current_path();

	iterColorDirPath.append("colorPalletes");
	iterCopy.append("imageData");
	iterCopy.append(ditherFileName + ".bmp");

	iterSave.append("imageData");
	iterSave.append("test");
	iterSave.append("");

	iterCsv.append("imageData");
	iterCsv.append("timeMeasurementHistory.csv");
	
	color.loadColors(iterColorDirPath);

	photo.copyBMP(iterCopy.string());

	//Prepare Photo

	const uint32_t c256 = 256;
	const uint32_t c16 = 16;
	const uint32_t c2 = 2;

	uint32_t numberOfColors = c2;

	ditherPhoto.setHeight(photo.getHeight());
	ditherPhoto.setWidth(photo.getWidth());
	ditherPhoto.setColorTable(color.getColors(0));
	ditherPhoto.setColorNumber(numberOfColors);
	ditherPhoto.setFileName(ditherFileName);
	ditherPhoto.getDataSize();
	
	//TODO SET BYTES
	
	//Prepare Photo End

	uint64_t numberOfClockCycles = 0;
	uint32_t newSize = 0;
	uint8_t alignBytesParameter = 8 / (std::ceil(std::log2(numberOfColors)));
	uint32_t rowSizeNoPadding = (ditherPhoto.getWidth() + alignBytesParameter - 1) / alignBytesParameter;
	uint32_t rowSizePadding = rowSizeNoPadding;

	if(rowSizeNoPadding % 4 != 0) rowSizePadding = rowSizeNoPadding + (4 - (rowSizeNoPadding % 4));

	uint32_t dataSizeWithPadding = rowSizePadding * ditherPhoto.getHeight();

	ditherPhoto.getDataSize() = dataSizeWithPadding;
	ditherPhoto.alignBytes();

	double* wsk = new double[photo.getWidth() * 3];
	bool Asmdll = true;

	auto start = std::chrono::high_resolution_clock::now();

	if (Asmdll) numberOfClockCycles = Procedure(ditherPhoto.getNumberOfColors(), ditherPhoto.getColorPalletePointer(), photo.getDataSize(), photo.getWidth(), photo.getHeight(), photo.getDataPointer(), ditherPhoto.getDataSize(), ditherPhoto.getDataPointer(), wsk);
	else numberOfClockCycles = applyJohnSteinberg(ditherPhoto.getNumberOfColors(), ditherPhoto.getColorPalletePointer(), photo.getDataSize(), photo.getWidth(), photo.getHeight(), photo.getDataPointer(), ditherPhoto.getDataSize(), ditherPhoto.getDataPointer(), wsk);

	auto end = std::chrono::high_resolution_clock::now();

	delete wsk;

	uint64_t microSeconds = std::chrono::duration_cast<std::chrono::microseconds>(end - start).count();
	uint64_t miliSeconds = std::chrono::duration_cast<std::chrono::milliseconds>(end - start).count();

	//Save time to csv


	std::vector<std::vector<std::string>> new_data = {
	{(Asmdll == true) ? "MASM" : "C++", std::to_string(photo.getDataSize()), std::to_string(ditherPhoto.getDataSize()), std::to_string(numberOfColors), std::to_string(numberOfClockCycles), std::to_string(microSeconds), std::to_string(miliSeconds)}
	};

	std::ofstream file(iterCsv.string(), std::ios::app);
	
	// Zapis danych do pliku CSV
	for (const auto& row : new_data) {
		for (size_t i = 0; i < row.size(); ++i) {
			// Dopisz ka¿d¹ wartoœæ z wiersza
			file << row[i];

			// Dodaj przecinek, ale nie na koñcu linii
			if (i != row.size() - 1) {
				file << "; ";
			}
		}
		// Zakoñcz wiersz
		file << std::endl;
	}

	// Zamkniêcie pliku
	file.close();


	ditherPhoto.setFileName("test0");

	ditherPhoto.makeHeader();
	ditherPhoto.makeDIB();
	ditherPhoto.storeBMP(iterSave.string());

	FreeLibrary(library);

	return 0;
}

