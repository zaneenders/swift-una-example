import Foundation
import SwiftFit
import Testing

@testable import RideDecoder

@Test func allSensorStreamsSurviveActualFITWriter() throws {
  let fixture = try FITWriterFixture.create()
  defer { fixture.remove() }
  let bytes = try Data(contentsOf: fixture.file)
  let options = FITDecodeOptions(validateFileCRC: true, validateHeaderCRC: true)
  let fit = try FITFile(bytes: Array(bytes), options: options)

  try validateDeveloperMetadata(fit)
  try validateSensorSamples(fit)
  try validateRideRecords(fit)
  try validateActivityMetadata(fit)
  let ride = try RideData(bytes: bytes)
  #expect(ride.samples.count == expectedSamples.count)
  for expected in expectedSamples {
    let stats = ride.statistics(for: expected.stream)
    #expect(stats.count == 1)
    #expect(stats.validCount == (expected.validity == .valid ? 1 : 0))
  }
  validateCorruptionRejection(bytes, options: options)
}

private func validateDeveloperMetadata(_ fit: FITFile) throws {
  #expect(fit.fileCRCValid)
  #expect(fit.headerCRCValid)
  #expect(fit.header.protocolVersion == 0x20)
  // SwiftFit's convenience map requires developer_id, which this writer omits.
  // Validate the decoded developer_data_id message directly instead.
  let developer = try #require(fit.messages.first { $0.globalMessageNumber == FITGlobalMessage.developerDataID })
  #expect(developer.uint8Field(number: 3) == 0)
  let applicationID = try #require(developer.field(number: 1))
  #expect(applicationID.baseType == .byte)
  #expect(
    applicationID.values
      == [
        0xE8, 0x7D, 0x0A, 0x49, 0xF3, 0xB1, 0x5C, 0x62,
        0, 0, 0, 0, 0, 0, 0, 0,
      ].map { .byte(UInt8($0)) })

  let fields: [(name: String, type: BaseType)] = [
    ("sensor_time_us", .uint64), ("stream", .uint32), ("valid", .uint32),
    ("a", .float32), ("b", .float32), ("c", .float32),
    ("d", .float32), ("e", .float32), ("f", .float32),
  ]
  for (index, field) in fields.enumerated() {
    let key = DeveloperFieldKey(
      developerDataIndex: FITSensorSample.developerIndex, fieldDefinitionNumber: SensorField.allCases[index].rawValue)
    let definition = try #require(fit.developerFieldDefinitions[key])
    #expect(definition.fieldName == field.name)
    #expect(definition.baseType == field.type)
  }
}

private func validateSensorSamples(_ fit: FITFile) throws {
  let messages = fit.messages.filter { $0.globalMessageNumber == FITSensorSample.messageNumber }
  let samples = try messages.map { try FITSensorSample(message: $0) }
  #expect(samples.count == expectedSamples.count)
  for (sample, expected) in zip(samples, expectedSamples) {
    #expect(sample.stream == expected.stream)
    #expect(sample.validity == expected.validity)
    #expect(sample.timestampMicroseconds == expected.timestampMicroseconds)
    #expect(sample.channels == expected.channels)
  }
}

private func validateRideRecords(_ fit: FITFile) throws {
  let records = fit.messages.filter { $0.globalMessageNumber == FITGlobalMessage.record }
  #expect(records.count == 2)
  let record = try #require(records.first)
  let expectedTimestamp: UInt32 = 1_800_000_001 - fitEpochOffset
  #expect(record.uint32Field(number: FITRecordField.timestamp) == expectedTimestamp)
  #expect(record.sint32Field(number: FITRecordField.positionLat) == Int32(40 * (2147483648.0 / 180)))
  #expect(record.sint32Field(number: FITRecordField.positionLong) == Int32(-74 * (2147483648.0 / 180)))
  #expect(record.uint32Field(number: enhancedAltitudeField) == 3000)
  #expect(record.uint32Field(number: FITRecordField.enhancedSpeed) == 5000)
  let invalidRecord = try #require(records.last)
  for field in [
    FITRecordField.positionLat, FITRecordField.positionLong,
    enhancedAltitudeField, FITRecordField.enhancedSpeed,
  ] {
    #expect(invalidRecord.firstValue(number: field) == .invalid)
  }
}

private func validateActivityMetadata(_ fit: FITFile) throws {
  let session = try #require(fit.messages.first { $0.globalMessageNumber == FITGlobalMessage.session })
  #expect(session.enumField(number: FITSessionField.sport) == FITSport.cycling.rawValue)
  #expect(session.enumField(number: FITSessionField.subSport) == mountainBikingSubSport)
  #expect(session.uint32Field(number: FITSessionField.totalTimerTime) == 2000)
  let activity = try #require(fit.messages.first { $0.globalMessageNumber == FITGlobalMessage.activity })
  #expect(activity.uint16Field(number: numberOfSessionsField) == 1)
  let events = fit.messages.filter { $0.globalMessageNumber == FITGlobalMessage.event }
  #expect(
    events.map { $0.enumField(number: eventTypeField) } == [FITEventType.start.rawValue, FITEventType.stopAll.rawValue])

}

private func validateCorruptionRejection(_ bytes: Data, options: FITDecodeOptions) {
  var corrupted = bytes
  corrupted[corrupted.count - 1] ^= 1
  #expect(throws: FITError.self) {
    try FITFile(bytes: Array(corrupted), options: options)
  }
  #expect(throws: FITError.self) { try RideData(bytes: corrupted) }
  var offset = 0
  #expect(throws: DecodeError.self) {
    try decodeRide(
      read: { count in
        let end = min(offset + count, corrupted.count)
        defer { offset = end }
        return corrupted.subdata(in: offset..<end)
      }, write: { _ in })
  }
}

private struct ExpectedSample {
  let stream: SensorStream
  let validity: SampleValidity
  let channels: [Float]

  // Distinct timestamp bytes make endian mistakes visible in the fixture.
  var timestampMicroseconds: UInt64 {
    0x0102_0304_0506_0700 + UInt64(stream.rawValue)
  }
}

private let expectedSamples: [ExpectedSample] = [
  ExpectedSample(stream: .acceleration, validity: .valid, channels: [10, -11, 12, -13, 14, -15]),
  ExpectedSample(stream: .gyroscope, validity: .valid, channels: [20, -21, 22, -23, 24, -25]),
  ExpectedSample(stream: .location, validity: .invalid, channels: [30, -31, 32, -33, 34, -35]),
  ExpectedSample(stream: .speed, validity: .valid, channels: [40, -41, 42, -43, 44, -45]),
  ExpectedSample(stream: .pressure, validity: .valid, channels: [50, -51, 52, -53, 54, -55]),
  ExpectedSample(stream: .magnetic, validity: .valid, channels: [60, -61, 62, -63, 64, -65]),
  ExpectedSample(stream: .distance, validity: .valid, channels: [70, -71, 72, -73, 74, -75]),
  ExpectedSample(stream: .clock, validity: .valid, channels: [80, -81, 82, -83, 84, -85]),
]

// FIT profile constants not yet exposed by SwiftFit.
private let enhancedAltitudeField: UInt8 = 78
private let numberOfSessionsField: UInt8 = 1
private let eventTypeField: UInt8 = 1
private let mountainBikingSubSport: UInt8 = 8
