#include "RideFitWriter.hpp"
#include <cassert>
#include <cstdio>
#include <cstring>
#include <vector>

class MemoryFile : public SDK::Interface::IFile {
public:
  std::vector<char> bytes;
  size_t position = 0;
  bool opened = true;
  bool failWrites = false;
  void setPath(const char *) override {}
  const char *getPath() const override { return "test.fit"; }
  bool exist() const override { return true; }
  bool rename(const char *) override { return false; }
  bool remove() override { return false; }
  size_t size() const override { return bytes.size(); }
  bool open(bool = false, bool overwrite = false) override {
    opened = true; position = 0;
    if (overwrite) bytes.clear();
    return true;
  }
  bool isOpen() const override { return opened; }
  bool close() override { opened = false; return true; }
  bool read(char *buffer, size_t count, size_t &got) override {
    got = std::min(count, bytes.size() - position);
    std::memcpy(buffer, bytes.data() + position, got); position += got;
    return opened;
  }
  bool write(const char *buffer, size_t count, size_t &written) override {
    written = 0;
    if (!opened || failWrites) return false;
    if (position + count > bytes.size()) bytes.resize(position + count);
    std::memcpy(bytes.data() + position, buffer, count); position += count;
    written = count; return true;
  }
  bool seek(size_t offset) override { position = offset; return true; }
  bool truncate(size_t offset) override { bytes.resize(offset); return true; }
  bool flush() override { return true; }
  size_t getPosition() const override { return position; }
};

int main(int argc, char **argv) {
  MemoryFile file;
  RideFitWriter writer(file);
  assert(writer.begin(1800000000));
  // Distinct values expose dropped streams, channel swaps and endian errors.
  for (uint32_t stream = 1; stream <= 8; ++stream) {
    uint8_t sample[40] = {};
    const uint64_t timestamp = 0x0102030405060700ULL + stream;
    for (unsigned byte = 0; byte < 8; ++byte)
      sample[byte] = static_cast<uint8_t>(timestamp >> (byte * 8));
    sample[8] = static_cast<uint8_t>(stream);
    sample[12] = stream == 3 ? 0 : 1;
    for (unsigned channel = 0; channel < 6; ++channel) {
      const float value = static_cast<float>(stream * 10 + channel) *
                          (channel % 2 == 0 ? 1.0f : -1.0f);
      uint32_t bits;
      std::memcpy(&bits, &value, sizeof(bits));
      for (unsigned byte = 0; byte < 4; ++byte)
        sample[16 + channel * 4 + byte] = static_cast<uint8_t>(bits >> (byte * 8));
    }
    assert(writer.sample(sample));
  }
  assert(writer.record(1800000001, true, 40, -74, 100, true, 5));
  assert(writer.record(1800000002, false, 0, 0, 0, false, 0));
  assert(writer.finish(1800000002,2000));
  assert(std::memcmp(file.bytes.data()+8,".FIT",4) == 0);
  auto *output = std::fopen(argc > 1 ? argv[1] : "/tmp/una-ride-test.fit","wb");
  assert(output);
  assert(std::fwrite(file.bytes.data(),1,file.bytes.size(),output) == file.bytes.size());
  std::fclose(output);
  MemoryFile broken;
  broken.failWrites = true;
  RideFitWriter failed(broken);
  assert(!failed.begin(1800000000));
  std::puts("FIT writer tests passed");
}
