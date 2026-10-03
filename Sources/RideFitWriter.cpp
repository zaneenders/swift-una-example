#include "RideFitWriter.hpp"
#include <cmath>
#include <cstring>

namespace {
using B = SDK::Fit::BaseType;
uint32_t fitTime(uint32_t utc) { return utc >= 631065600 ? utc - 631065600 : 0; }
}

bool RideFitWriter::begin(uint32_t utc) {
  startUtc = utc;
  if (!writer.begin(0)) return false;
  writer.defineMessage(0, 0, {{0,B::Enum},{1,B::UInt16},{4,B::UInt32}});
  writer.data(0).u8(4).u16(255).u32(fitTime(utc)).write();
  writer.defineMessage(1, 207, {{1,B::Byte,16},{3,B::UInt8}});
  const uint8_t app[16] = {0xE8,0x7D,0x0A,0x49,0xF3,0xB1,0x5C,0x62};
  writer.data(1).bytes(app,16).u8(0).write();
  const auto describe = [this](uint8_t field, const char *name, const char *units, B type) {
    const auto nameLength = static_cast<uint8_t>(std::strlen(name)+1);
    const auto unitLength = static_cast<uint8_t>(std::strlen(units)+1);
    writer.defineMessage(2,206,{{0,B::UInt8},{1,B::UInt8},{2,B::UInt8},
                              {3,B::String,nameLength},{8,B::String,unitLength}});
    writer.data(2).u8(0).u8(field).u8(static_cast<uint8_t>(type))
      .str(name,nameLength).str(units,unitLength).write();
  };
  describe(0,"sensor_time_us","us",B::UInt64);
  describe(1,"stream","id",B::UInt32);
  describe(2,"valid","bool",B::UInt32);
  const char *names[8][6] = {
    {"accel_x","accel_y","accel_z","reserved","reserved","reserved"},
    {"gyro_x","gyro_y","gyro_z","reserved","reserved","reserved"},
    {"latitude","longitude","gps_altitude","precision","reserved","reserved"},
    {"speed","reserved","reserved","reserved","reserved","reserved"},
    {"pressure","reference_pressure","barometric_altitude","reserved","reserved","reserved"},
    {"mag_x","mag_y","mag_z","mag_calibrated","reserved","reserved"},
    {"distance","reserved","reserved","reserved","reserved","reserved"},
    {"utc_high16","utc_low16","reserved","reserved","reserved","reserved"}
  };
  const char *units[8][6] = {
    {"driver-native","driver-native","driver-native","","",""},
    {"driver-native","driver-native","driver-native","","",""},
    {"deg","deg","m","m","",""}, {"m/s","","","","",""},
    {"Pa","Pa","m","","",""}, {"uT","uT","uT","bool","",""},
    {"m","","","","",""}, {"UTC seconds high16","UTC seconds low16","","","",""}
  };
  for (uint8_t stream = 0; stream < 8; ++stream) {
    const uint8_t first = 10 + stream * 6;
    for (uint8_t channel = 0; channel < 6; ++channel)
      describe(first+channel,names[stream][channel],units[stream][channel],B::Float32);
    writer.defineMessage(8+stream,0xFF01+stream,{},
      {{0,8,0},{1,4,0},{2,4,0},{first,4,0},{static_cast<uint8_t>(first+1),4,0},
       {static_cast<uint8_t>(first+2),4,0},{static_cast<uint8_t>(first+3),4,0},
       {static_cast<uint8_t>(first+4),4,0},{static_cast<uint8_t>(first+5),4,0}});
  }
  // Schema v2; requested periods (ms) in stream-ID order. Zero means service tick.
  writer.defineMessage(3,0xFF10,{{0,B::UInt16},{1,B::UInt32,8}});
  writer.data(3).u16(2).u32(20).u32(20).u32(1000).u32(1000)
    .u32(100).u32(50).u32(1000).u32(0).write();
  writer.defineMessage(4,20,{{253,B::UInt32},{0,B::SInt32},{1,B::SInt32},
                            {78,B::UInt32},{73,B::UInt32}});
  writer.defineMessage(5,21,{{253,B::UInt32},{0,B::Enum},{1,B::Enum}});
  writer.data(5).u32(fitTime(utc)).u8(0).u8(0).write();
  writer.defineMessage(6,18,{{253,B::UInt32},{2,B::UInt32},{7,B::UInt32},
                            {8,B::UInt32},{5,B::Enum},{6,B::Enum}});
  writer.defineMessage(7,34,{{253,B::UInt32},{0,B::UInt32},{1,B::UInt16},
                            {2,B::Enum},{3,B::Enum},{4,B::Enum}});
  return writer.ok();
}

bool RideFitWriter::sample(const uint8_t *encoded) {
  const uint32_t stream = static_cast<uint32_t>(encoded[8]) |
    static_cast<uint32_t>(encoded[9]) << 8 | static_cast<uint32_t>(encoded[10]) << 16 |
    static_cast<uint32_t>(encoded[11]) << 24;
  if (stream < 1 || stream > 8) return false;
  return writer.data(static_cast<uint8_t>(7+stream)).bytes(encoded,40).write();
}

bool RideFitWriter::record(uint32_t utc, bool fix, float latitude, float longitude,
                          float altitude, bool speedValid, float speed) {
  auto data = writer.data(4);
  data.u32(fitTime(utc));
  if (fix && std::isfinite(latitude) && std::isfinite(longitude) &&
      std::abs(latitude) <= 90 && std::abs(longitude) < 180) {
    data.i32(static_cast<int32_t>(latitude * (2147483648.0/180)))
        .i32(static_cast<int32_t>(longitude * (2147483648.0/180)));
  } else {
    data.invalid(B::SInt32).invalid(B::SInt32);
  }
  if (fix && std::isfinite(altitude) && altitude >= -500 && altitude < 100000)
    data.u32(static_cast<uint32_t>((altitude+500)*5));
  else data.invalid(B::UInt32);
  if (speedValid && std::isfinite(speed) && speed >= 0 && speed < 1000)
    data.u32(static_cast<uint32_t>(speed*1000));
  else data.invalid(B::UInt32);
  return data.write();
}

bool RideFitWriter::finish(uint32_t utc, uint32_t durationMs) {
  writer.data(5).u32(fitTime(utc)).u8(0).u8(4).write();
  writer.data(6).u32(fitTime(utc)).u32(fitTime(startUtc)).u32(durationMs)
      .u32(durationMs).u8(2).u8(8).write(); // cycling / mountain biking
  writer.data(7).u32(fitTime(utc)).u32(durationMs).u16(1).u8(0).u8(26).u8(1).write();
  return writer.finish() && writer.ok();
}
