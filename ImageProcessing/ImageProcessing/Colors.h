#ifndef COLORS_H
#define COLORS_H

#include <iostream>
#include <filesystem>
#include <fstream>

class Colors
{
private:
	unsigned char** colorTab;
	void clear();
public:
	void loadColors(std::filesystem::path& pathOfColors);
	unsigned char* getColors(int color);

	Colors();
	~Colors();
};

#endif // !COLORS_H
