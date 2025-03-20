#include "BMP.hpp"
#include <iostream>

BMP::~BMP()
{
	if (dataPtr != nullptr) delete dataPtr;
	dataPtr = nullptr;


}

bool BMP::copyBMP(std::string nameOfFileToCopy)
{
	//Open file
	std::fstream bmpStream;
	bmpStream.open(nameOfFileToCopy, std::ios::in | std::ios::binary);
	if (!bmpStream.is_open()) return false;

	//HEADER BMP
	bmpStream.read((char*)(& this->bitmapHeader.ID), sizeof(this->bitmapHeader.ID));
	bmpStream.read((char*)(& this->bitmapHeader.bmpSize), sizeof(this->bitmapHeader.bmpSize));
	bmpStream.read((char*)(& this->bitmapHeader.unused), sizeof(this->bitmapHeader.unused));
	bmpStream.read((char*)(& this->bitmapHeader.unused2), sizeof(this->bitmapHeader.unused2));
	bmpStream.read((char*)(& this->bitmapHeader.offsetPixelArray), sizeof(this->bitmapHeader.offsetPixelArray));

	//HEADER DIB
	bmpStream.read((char*)(&this->dibHeader.numberOfBytesInDIB), sizeof(this->dibHeader.numberOfBytesInDIB));
	bmpStream.read((char*)(&this->dibHeader.widthOfBitMap), sizeof(this->dibHeader.widthOfBitMap));
	bmpStream.read((char*)(&this->dibHeader.heighOfBitMap), sizeof(this->dibHeader.heighOfBitMap));
	bmpStream.read((char*)(&this->dibHeader.numberOfColorPlanes), sizeof(this->dibHeader.numberOfColorPlanes));
	bmpStream.read((char*)(&this->dibHeader.numberOfBitsPerPixel), sizeof(this->dibHeader.numberOfBitsPerPixel));
	bmpStream.read((char*)(&this->dibHeader.pixelCompression), sizeof(this->dibHeader.pixelCompression));
	bmpStream.read((char*)(&this->dibHeader.sizeOfDataWithPadding), sizeof(this->dibHeader.sizeOfDataWithPadding));
	bmpStream.read((char*)(&this->dibHeader.printResolutionHorizontal), sizeof(this->dibHeader.printResolutionHorizontal));
	bmpStream.read((char*)(&this->dibHeader.printResolutionVertical), sizeof(this->dibHeader.printResolutionVertical));
	bmpStream.read((char*)(&this->dibHeader.numberOfColorUsed), sizeof(this->dibHeader.numberOfColorUsed));
	bmpStream.read((char*)(&this->dibHeader.somethingImportant), sizeof(this->dibHeader.somethingImportant));

	//SKIP COLOR PALETTE AND LOAD DATA 
	bmpStream.seekg(this->bitmapHeader.offsetPixelArray, std::ios::beg);

	//this->numberOfDataBytes = this->bitmapHeader.bmpSize - this->bitmapHeader.offsetPixelArray;
	this->numberOfDataBytes = this->dibHeader.sizeOfDataWithPadding;
	
	this->dataPtr = new unsigned char[this->numberOfDataBytes];

	bmpStream.read((char*)this->dataPtr, (this->numberOfDataBytes));
	bmpStream.close();
	return true;
}

bool BMP::storeBMP(std::string pathOfCopyDir)
{
	
	std::fstream bmpStream;
	bmpStream.open(pathOfCopyDir + this->fileName + ".bmp", std::ios::out | std::ios::binary);

	if (!bmpStream.is_open()) return false;
	//HEADER BMP
	bmpStream.write((char*)(& this->bitmapHeader.ID), sizeof(this->bitmapHeader.ID));
	bmpStream.write((char*)(& this->bitmapHeader.bmpSize), sizeof(this->bitmapHeader.bmpSize));
	bmpStream.write((char*)(& this->bitmapHeader.unused), sizeof(this->bitmapHeader.unused));
	bmpStream.write((char*)(& this->bitmapHeader.unused2), sizeof(this->bitmapHeader.unused2));
	bmpStream.write((char*)(& this->bitmapHeader.offsetPixelArray), sizeof(this->bitmapHeader.offsetPixelArray));

	//HEADER DIB
	bmpStream.write((char*)(&this->dibHeader.numberOfBytesInDIB), sizeof(this->dibHeader.numberOfBytesInDIB));
	bmpStream.write((char*)(&this->dibHeader.widthOfBitMap), sizeof(this->dibHeader.widthOfBitMap));
	bmpStream.write((char*)(&this->dibHeader.heighOfBitMap), sizeof(this->dibHeader.heighOfBitMap));
	bmpStream.write((char*)(&this->dibHeader.numberOfColorPlanes), sizeof(this->dibHeader.numberOfColorPlanes));
	bmpStream.write((char*)(&this->dibHeader.numberOfBitsPerPixel), sizeof(this->dibHeader.numberOfBitsPerPixel));
	bmpStream.write((char*)(&this->dibHeader.pixelCompression), sizeof(this->dibHeader.pixelCompression));
	bmpStream.write((char*)(&this->dibHeader.sizeOfDataWithPadding), sizeof(this->dibHeader.sizeOfDataWithPadding));
	bmpStream.write((char*)(&this->dibHeader.printResolutionHorizontal), sizeof(this->dibHeader.printResolutionHorizontal));
	bmpStream.write((char*)(&this->dibHeader.printResolutionVertical), sizeof(this->dibHeader.printResolutionVertical));
	bmpStream.write((char*)(&this->dibHeader.numberOfColorUsed), sizeof(this->dibHeader.numberOfColorUsed));
	bmpStream.write((char*)(&this->dibHeader.somethingImportant), sizeof(this->dibHeader.somethingImportant));

	//SAVING PALETTE

	if (this->dibHeader.numberOfBitsPerPixel <= 8)
	{
		bmpStream.write((char*)(this->colors), this->numberOfColors * 4);
	}

	//Data Writing

	bmpStream.write((char*)this->dataPtr, this->numberOfDataBytes);
	bmpStream.close();

	return true;
}

unsigned char* BMP::getDataPointer()
{
	return this->dataPtr;
}

unsigned char* BMP::getColorPalletePointer() const
{
	return this->colors;
}

unsigned char*& BMP::getDataReferencePointer()
{
	return this->dataPtr;
}

uint32_t& BMP::getDataSize()
{
	return this->numberOfDataBytes;
}

uint32_t& BMP::getDibSizeOfData()
{
	return this->dibHeader.sizeOfDataWithPadding;
}


uint32_t BMP::getWidth() const
{
	return this->dibHeader.widthOfBitMap;
}

uint32_t BMP::getHeight() const 
{
	return this->dibHeader.heighOfBitMap;
}

uint32_t BMP::getNumberOfColors() const
{
	return this->numberOfColors;
}

void BMP::setColorNumber(const uint32_t& numberOfColors)
{
	this->numberOfColors = numberOfColors;
}

void BMP::setColorTable(unsigned char* const colorPallete)
{
	this->colors = colorPallete;

}

void BMP::setWidth(const uint32_t& width)
{
	this->dibHeader.widthOfBitMap = width;
}

void BMP::setHeight(const uint32_t& height)
{
	this->dibHeader.heighOfBitMap = height;
}

void BMP::setFileName(const std::string& nameOfFile)
{
	this->fileName = nameOfFile;
}

void BMP::makeHeader()
{
	this->bitmapHeader.ID = 0x4D42;
	this->bitmapHeader.bmpSize= 40 + 14 + this->numberOfDataBytes + 4 * this->numberOfColors;
	this->bitmapHeader.unused= 0x0;
	this->bitmapHeader.unused2 = 0x0;
	this->bitmapHeader.offsetPixelArray = 40 + 14 + 4 * this->numberOfColors;

}

void BMP::makeDIB()
{
	this->dibHeader.numberOfBytesInDIB = 40;
	//height already set
	//width already set
	this->dibHeader.numberOfColorPlanes = 1;
	this->dibHeader.numberOfBitsPerPixel = std::round(std::log2(this->numberOfColors));
	this->dibHeader.pixelCompression = 0;
	this->dibHeader.sizeOfDataWithPadding = this->numberOfDataBytes;
	this->dibHeader.printResolutionHorizontal = 0;
	this->dibHeader.printResolutionVertical = 0;
	this->dibHeader.numberOfColorUsed = 0;
	this->dibHeader.somethingImportant = 0;
}
	
void BMP::printHeaderData()
{
	std::cout << "ID: " << bitmapHeader.ID << std::endl;
	std::cout << "BMP SIZE: " << bitmapHeader.bmpSize << std::endl;
}

void BMP::alignBytes()
{
	this->dataPtr = new unsigned char[numberOfDataBytes];
	std::fill(dataPtr, dataPtr + numberOfDataBytes, 0);
}


