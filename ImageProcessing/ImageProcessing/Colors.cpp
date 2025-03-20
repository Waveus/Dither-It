#include "Colors.h"

void Colors::clear()
{
	if (colorTab != nullptr)
	{
		for (int i = 0; i < 3;i++)
		{
			delete[] this->colorTab[i];
			this->colorTab[i] = nullptr;
		}
		delete[] this->colorTab;
		this->colorTab = nullptr;
	}
}

void Colors::loadColors(std::filesystem::path& pathOfColors)
{
	this->colorTab = new unsigned char*[3];
	bool colors2Found = false, colors16Found = false, colors256Found = false;
	std::fstream str;
	std::string actualFileName;

	for (const auto& dirEntry : std::filesystem::directory_iterator(pathOfColors))
	{
		if (dirEntry.is_regular_file())
		{
			actualFileName = dirEntry.path().filename().string();

			if (actualFileName == "2Colors.hex")
			{
				colors2Found = true;
				str.open(dirEntry.path().string(), std::ios::binary | std::ios::in);
				if (!str.is_open()) std::cout << "file " << dirEntry << " cannot be open";

				str.seekg(0, std::ios::end);
				std::streamsize sizeOfFile = str.tellg();
				str.seekg(0, std::ios::beg);

				this->colorTab[0] = new unsigned char[sizeOfFile];
				str.read((char*)colorTab[0], sizeOfFile);
				str.close();
			}
			else if (actualFileName == "16Colors.hex")
			{
				colors16Found = true;
				str.open(dirEntry.path().string(), std::ios::binary | std::ios::in);
				if (!str.is_open()) std::cout << "file " << dirEntry << " cannot be open";

				str.seekg(0, std::ios::end);
				std::streamsize sizeOfFile = str.tellg();
				str.seekg(0, std::ios::beg);
				std::cout << sizeOfFile << std::endl;

				this->colorTab[1] = new unsigned char[sizeOfFile];
				str.read((char*)colorTab[1], sizeOfFile);
				str.close();
			}
			else if (actualFileName == "256Colors.hex") 
			{ 
				colors256Found = true; 
				str.open(dirEntry.path().string(), std::ios::binary | std::ios::in);
				if (!str.is_open()) std::cout << "file " << dirEntry << " cannot be open";

				str.seekg(0, std::ios::end);
				std::streamsize sizeOfFile = str.tellg();
				str.seekg(0, std::ios::beg);

				std::cout << sizeOfFile << std::endl;

				this->colorTab[2] = new unsigned char[sizeOfFile];
				str.read((char*)colorTab[2], sizeOfFile);
				str.close();
			}
			else continue;

		}
	}
}

unsigned char* Colors::getColors(int color)
{
	return this->colorTab[color];
}

Colors::Colors()
{
	this->colorTab = nullptr;
}

Colors::~Colors()
{
	clear();
}
