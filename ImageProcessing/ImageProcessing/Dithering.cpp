#include "Dithering.h"



unsigned char findNearestColorIndexReturn(const uint32_t& numberOfColors, unsigned char* colorTable, const uint8_t& colorBlue, const uint8_t& colorGreen, const uint8_t& colorRed)
{
	uint32_t minDifference = std::numeric_limits<uint32_t>::max();
	unsigned char nearestColor = 0;
	
	for (uint32_t i = 0; i < numberOfColors; i++)
	{
		int16_t currentColorBlue = (int16_t)colorTable[i * 4];
		int16_t currentColorGreen = (int16_t)colorTable[i * 4 + 1];
		int16_t currentColorRed = (int16_t)colorTable[i * 4 + 2];

		uint32_t difference = (currentColorBlue - colorBlue) * (currentColorBlue - colorBlue) + (currentColorGreen - colorGreen) * (currentColorGreen - colorGreen) + (currentColorRed - colorRed) * (currentColorRed - colorRed);

		if (difference < minDifference)
		{
			minDifference = difference;
			nearestColor = i;
		}
	}

	return nearestColor;
}

void universalIndexSave(unsigned char& dataContainer, unsigned char& index, uint8_t alignBytesParameter, uint32_t pixelNumber)
{
	
	if (alignBytesParameter == 1) {
		// 8-bitowy kolor: ka¿dy piksel zajmuje pe³ny bajt
		dataContainer = index;
	}
	else if (alignBytesParameter == 2) {
		// 4-bitowy kolor: dwa piksele na jeden bajt
		uint8_t bitOffset = 4 - (pixelNumber % alignBytesParameter) * 4; // Offset: 4 dla pierwszego piksela, 0 dla drugiego
		dataContainer |= (index & 0xF) << bitOffset; // Zapisanie indeksu na w³aœciwej pozycji
	}
	else if (alignBytesParameter == 8) {
		// Zapisujemy 1-bitowy kolor (jeden bit na piksel)
		uint8_t offset = 7 - (pixelNumber % alignBytesParameter);  // Okreœlamy, który bit w bajcie bêdziemy zapisywaæ
		// Przesuwamy "index" do odpowiedniego bitu w bajcie
		if (index & 0x01) {
			dataContainer |= (1 << offset);  // Ustawiamy odpowiedni bit w dataContainer
		}
	}

}

uint64_t applyJohnSteinberg(const uint32_t& numberOfColors, unsigned char* colorTable, uint32_t& sizeIn, const uint32_t& width, const uint32_t& height, unsigned char* dataIn, uint32_t& sizeOut, unsigned char* dataOut, double* errorTable)
{

	uint64_t startTick = __rdtsc();
	uint8_t alignBytesParameter = 8 / (std::ceil(std::log2(numberOfColors)));
	if (numberOfColors == 256) alignBytesParameter = 1;
	else if (numberOfColors == 16) alignBytesParameter = 2;
	else if (numberOfColors == 1) alignBytesParameter = 8;
	
	uint32_t rowSizePadding = sizeOut / height;

	uint32_t nearestColorIndex = 0;

	for (uint32_t i = 0; i < height; i++)
	{

		double diagonalErrorBuffer[3] = {0,0,0};

		for (uint32_t j = 0; j < width; j++)
		{
		
			uint32_t pixel = *((uint32_t*)(&dataIn[ sizeIn / height * i + 3 * j]));
			
			double trueBlue = errorTable[3 * j] + ((uint8_t*)(&pixel))[0]; 
			double trueGreen = errorTable[3 * j + 1] + ((uint8_t*)(&pixel))[1];
			double trueRed = errorTable[3 * j + 2] + ((uint8_t*)(&pixel))[2];

			trueBlue = std::clamp(trueBlue, -300.0, 300.0);
			trueGreen = std::clamp(trueGreen, -300.0, 300.0);
			trueRed = std::clamp(trueRed, -300.0, 300.0);


			uint8_t colorBlue = std::clamp((int)std::round(trueBlue), 0, 255);
			uint8_t colorGreen = std::clamp((int)std::round(trueGreen), 0, 255);
			uint8_t colorRed = std::clamp((int)std::round(trueRed), 0, 255);

			unsigned char index = findNearestColorIndexReturn(numberOfColors, colorTable, colorBlue, colorGreen, colorRed);
			
			//First bit aligment

			universalIndexSave(dataOut[rowSizePadding * i + j / alignBytesParameter], index, alignBytesParameter, j);

			if (j > 0)
			{
				errorTable[3 * (j - 1)] += (trueBlue - colorTable[index * 4]) * 3.0 / 16.0;
				errorTable[3 * (j - 1) + 1] += (trueGreen - colorTable[index * 4 + 1]) * 3.0 / 16.0;
				errorTable[3 * (j - 1) + 2] += (trueRed - colorTable[index * 4 + 2]) * 3.0 / 16.0;
			}

			errorTable[3 * (j)] = (double)(trueBlue - colorTable[index * 4]) * 5.0 / 16.0 + diagonalErrorBuffer[0];
			errorTable[3 * (j)+1] = (double)(trueGreen - colorTable[index * 4 + 1]) * 5.0 / 16.0 + diagonalErrorBuffer[1];
			errorTable[3 * (j)+2] = (double)(trueRed - colorTable[index * 4 + 2]) * 5.0 / 16.0 + diagonalErrorBuffer[2];
			
			if (j + 1 < width)
			{
				errorTable[3 * (j + 1)] += (double)(trueBlue - colorTable[index * 4]) * 7.0 / 16.0;
				errorTable[3 * (j + 1) + 1] += (double)(trueGreen - colorTable[index * 4 + 1]) *  7.0 / 16.0;
				errorTable[3 * (j + 1) + 2] += (double)(trueRed - colorTable[index * 4 + 2]) * 7.0 / 16.0;
			}
				diagonalErrorBuffer[0] = (double)(trueBlue - colorTable[index * 4]) * 1.0 / 16.0;
				diagonalErrorBuffer[1] = (double)(trueGreen - colorTable[index * 4 + 1]) * 1.0 / 16.0;
				diagonalErrorBuffer[2] = (double)(trueRed - colorTable[index * 4 + 2]) * 1.0 / 16.0;
		}
		
	}
	
	uint64_t endTick = __rdtsc();

	return { endTick - startTick };

}

