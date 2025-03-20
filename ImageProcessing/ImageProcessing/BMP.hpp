#ifndef BMP_H
#define BMP_H

#include <cstdint>
#include <filesystem>
#include <cstddef>
#include <stdint.h>
#include <fstream>


class BMP
{
protected:

	struct {
		uint16_t ID; //default "BM"
		uint32_t bmpSize; //not const 
		uint16_t unused;
		uint16_t unused2;
		uint32_t offsetPixelArray; //const depeds
	} bitmapHeader;

	struct {
		uint32_t numberOfBytesInDIB; //const
		uint32_t widthOfBitMap;		//const
		uint32_t heighOfBitMap;		//const
		uint16_t numberOfColorPlanes; //const
		uint16_t numberOfBitsPerPixel; //notconst
		uint32_t pixelCompression;  //const
		uint32_t sizeOfDataWithPadding; //notconst
		uint32_t printResolutionHorizontal; //const
		uint32_t printResolutionVertical; //const
		uint32_t numberOfColorUsed; //not const
		uint32_t somethingImportant; //const
	}dibHeader;

	std::string fileName;

	uint32_t numberOfColors; //const
	unsigned char* colors; //const

	uint32_t numberOfDataBytes; //No necessary ONLY FOR TESTING
	unsigned char* dataPtr;

public:

	~BMP();

	bool copyBMP(std::string nameOfFileToCopy);
	bool storeBMP(std::string nameOfFileToCopy);
	
	unsigned char* getDataPointer();
	unsigned char* getColorPalletePointer() const;
	unsigned char*& getDataReferencePointer();
	uint32_t& getDataSize();

	uint32_t getWidth() const;		
	uint32_t getHeight() const;
	uint32_t getNumberOfColors() const;
	
	void setColorNumber(const uint32_t& numberOfColors);
	void setColorTable(unsigned char* const colorPallete);
	void setWidth(const uint32_t& width);
	void setHeight(const uint32_t& height);
	void setFileName(const std::string& nameOfFile);

	void makeHeader();
	void makeDIB();
	
	uint32_t& getDibSizeOfData();

	void printHeaderData();
	void alignBytes();

};
#endif
