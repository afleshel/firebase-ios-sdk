/*
 * Copyright 2017 Google
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

#import <FirebaseFirestore/FIRTimestamp.h>
#import <FirebaseFirestore/FirebaseFirestore.h>

#import <XCTest/XCTest.h>

#import "Firestore/core/src/firebase/firestore/util/warnings.h"

#import "Firestore/Source/Core/FSTFirestoreClient.h"

#import "Firestore/Example/Tests/Util/FSTIntegrationTestCase.h"

@interface FIRFieldsTests : FSTIntegrationTestCase
@end

NSDictionary<NSString *, id> *testDataWithTimestamps(FIRTimestamp *timestamp) {
  return @{@"timestamp" : timestamp, @"nested" : @{@"timestamp2" : timestamp}};
}

@implementation FIRFieldsTests

- (NSDictionary<NSString *, id> *)testNestedDataNumbered:(int)number {
  return @{
    @"name" : [NSString stringWithFormat:@"room %d", number],
    @"metadata" : @{
      @"createdAt" : @(number),
      @"deep" : @{@"field" : [NSString stringWithFormat:@"deep-field-%d", number]}
    }
  };
}

- (void)testNestedFieldsCanBeWrittenWithSet {
  NSDictionary<NSString *, id> *testData = [self testNestedDataNumbered:1];

  FIRDocumentReference *doc = [self documentRef];
  [self writeDocumentRef:doc data:testData];

  FIRDocumentSnapshot *result = [self readDocumentForRef:doc];
  XCTAssertEqualObjects(result.data, testData);
}

- (void)testNestedFieldsCanBeReadDirectly {
  NSDictionary<NSString *, id> *testData = [self testNestedDataNumbered:1];

  FIRDocumentReference *doc = [self documentRef];
  [self writeDocumentRef:doc data:testData];

  FIRDocumentSnapshot *result = [self readDocumentForRef:doc];
  XCTAssertEqualObjects(result[@"name"], testData[@"name"]);
  XCTAssertEqualObjects(result[@"metadata"], testData[@"metadata"]);
  XCTAssertEqualObjects(result[@"metadata.deep.field"], testData[@"metadata"][@"deep"][@"field"]);
  XCTAssertNil(result[@"metadata.nofield"]);
  XCTAssertNil(result[@"nometadata.nofield"]);
}

- (void)testNestedFieldsCanBeUpdated {
  NSDictionary<NSString *, id> *testData = [self testNestedDataNumbered:1];

  FIRDocumentReference *doc = [self documentRef];
  [self writeDocumentRef:doc data:testData];
  [self updateDocumentRef:doc data:@{@"metadata.deep.field" : @100, @"metadata.added" : @200}];

  FIRDocumentSnapshot *result = [self readDocumentForRef:doc];
  XCTAssertEqualObjects(
      result.data, (@{
        @"name" : @"room 1",
        @"metadata" : @{@"createdAt" : @1, @"deep" : @{@"field" : @100}, @"added" : @200}
      }));
}

- (void)testNestedFieldsCanBeUsedInQueryFilters {
  NSDictionary<NSString *, NSDictionary<NSString *, id> *> *testDocs = @{
    @"1" : [self testNestedDataNumbered:300],
    @"2" : [self testNestedDataNumbered:100],
    @"3" : [self testNestedDataNumbered:200]
  };

  // inequality adds implicit sort on field
  NSArray<NSDictionary<NSString *, id> *> *expected =
      @[ [self testNestedDataNumbered:200], [self testNestedDataNumbered:300] ];
  FIRCollectionReference *coll = [self collectionRefWithDocuments:testDocs];

  FIRQuery *q = [coll queryWhereField:@"metadata.createdAt" isGreaterThanOrEqualTo:@200];
  FIRQuerySnapshot *results = [self readDocumentSetForRef:q];
  XCTAssertEqualObjects(FIRQuerySnapshotGetData(results), (expected));
}

- (void)testNestedFieldsCanBeUsedInOrderBy {
  NSDictionary<NSString *, NSDictionary<NSString *, id> *> *testDocs = @{
    @"1" : [self testNestedDataNumbered:300],
    @"2" : [self testNestedDataNumbered:100],
    @"3" : [self testNestedDataNumbered:200]
  };
  FIRCollectionReference *coll = [self collectionRefWithDocuments:testDocs];

  XCTestExpectation *queryCompletion = [self expectationWithDescription:@"query"];
  FIRQuery *q = [coll queryOrderedByField:@"metadata.createdAt"];
  [q getDocumentsWithCompletion:^(FIRQuerySnapshot *results, NSError *error) {
    XCTAssertNil(error);
    XCTAssertEqualObjects(FIRQuerySnapshotGetData(results), (@[
                            [self testNestedDataNumbered:100], [self testNestedDataNumbered:200],
                            [self testNestedDataNumbered:300]
                          ]));
    [queryCompletion fulfill];
  }];
  [self awaitExpectations];
}

/**
 * Creates test data with special characters in field names. Datastore currently prohibits mixing
 * nested data with special characters so tests that use this data must be separate.
 */
- (NSDictionary<NSString *, id> *)testDottedDataNumbered:(int)number {
  return @{
    @"a" : [NSString stringWithFormat:@"field %d", number],
    @"b.dot" : @(number),
    @"c\\slash" : @(number)
  };
}

- (void)testFieldsWithSpecialCharsCanBeWrittenWithSet {
  NSDictionary<NSString *, id> *testData = [self testDottedDataNumbered:1];

  FIRDocumentReference *doc = [self documentRef];
  [self writeDocumentRef:doc data:testData];

  FIRDocumentSnapshot *result = [self readDocumentForRef:doc];
  XCTAssertEqualObjects(result.data, testData);
}

- (void)testFieldsWithSpecialCharsCanBeReadDirectly {
  NSDictionary<NSString *, id> *testData = [self testDottedDataNumbered:1];

  FIRDocumentReference *doc = [self documentRef];
  [self writeDocumentRef:doc data:testData];

  FIRDocumentSnapshot *result = [self readDocumentForRef:doc];
  XCTAssertEqualObjects(result[@"a"], testData[@"a"]);
  XCTAssertEqualObjects(result[[[FIRFieldPath alloc] initWithFields:@[ @"b.dot" ]]],
                        testData[@"b.dot"]);
  XCTAssertEqualObjects(result[@"c\\slash"], testData[@"c\\slash"]);
}

- (void)testFieldsWithSpecialCharsCanBeUpdated {
  if ([FSTIntegrationTestCase isRunningAgainstEmulator]) return;  // b/112104025

  NSDictionary<NSString *, id> *testData = [self testDottedDataNumbered:1];

  FIRDocumentReference *doc = [self documentRef];
  [self writeDocumentRef:doc data:testData];
  [self updateDocumentRef:doc
                     data:@{
                       (id)[[FIRFieldPath alloc] initWithFields:@[ @"b.dot" ]] : @100,
                       (id) @"c\\slash" : @200
                     }];

  FIRDocumentSnapshot *result = [self readDocumentForRef:doc];
  XCTAssertEqualObjects(result.data, (@{@"a" : @"field 1", @"b.dot" : @100, @"c\\slash" : @200}));
}

- (void)testFieldsWithSpecialCharsCanBeUsedInQueryFilters {
  if ([FSTIntegrationTestCase isRunningAgainstEmulator]) return;  // b/112104025

  NSDictionary<NSString *, NSDictionary<NSString *, id> *> *testDocs = @{
    @"1" : [self testDottedDataNumbered:300],
    @"2" : [self testDottedDataNumbered:100],
    @"3" : [self testDottedDataNumbered:200]
  };

  // inequality adds implicit sort on field
  NSArray<NSDictionary<NSString *, id> *> *expected =
      @[ [self testDottedDataNumbered:200], [self testDottedDataNumbered:300] ];
  FIRCollectionReference *coll = [self collectionRefWithDocuments:testDocs];

  XCTestExpectation *queryCompletion = [self expectationWithDescription:@"query"];
  FIRQuery *q = [coll queryWhereFieldPath:[[FIRFieldPath alloc] initWithFields:@[ @"b.dot" ]]
                   isGreaterThanOrEqualTo:@200];
  [q getDocumentsWithCompletion:^(FIRQuerySnapshot *results, NSError *error) {
    XCTAssertNil(error);
    XCTAssertEqualObjects(FIRQuerySnapshotGetData(results), expected);
    [queryCompletion fulfill];
  }];

  [self awaitExpectations];
}

- (void)testFieldsWithSpecialCharsCanBeUsedInOrderBy {
  if ([FSTIntegrationTestCase isRunningAgainstEmulator]) return;  // b/112104025

  NSDictionary<NSString *, NSDictionary<NSString *, id> *> *testDocs = @{
    @"1" : [self testDottedDataNumbered:300],
    @"2" : [self testDottedDataNumbered:100],
    @"3" : [self testDottedDataNumbered:200]
  };

  NSArray<NSDictionary<NSString *, id> *> *expected = @[
    [self testDottedDataNumbered:100], [self testDottedDataNumbered:200],
    [self testDottedDataNumbered:300]
  ];
  FIRCollectionReference *coll = [self collectionRefWithDocuments:testDocs];

  FIRQuery *q = [coll queryOrderedByFieldPath:[[FIRFieldPath alloc] initWithFields:@[ @"b.dot" ]]];
  XCTestExpectation *queryDot = [self expectationWithDescription:@"query dot"];
  [q getDocumentsWithCompletion:^(FIRQuerySnapshot *results, NSError *error) {
    XCTAssertNil(error);
    XCTAssertEqualObjects(FIRQuerySnapshotGetData(results), expected);
    [queryDot fulfill];
  }];
  [self awaitExpectations];

  XCTestExpectation *querySlash = [self expectationWithDescription:@"query slash"];
  q = [coll queryOrderedByField:@"c\\slash"];
  [q getDocumentsWithCompletion:^(FIRQuerySnapshot *results, NSError *error) {
    XCTAssertNil(error);
    XCTAssertEqualObjects(FIRQuerySnapshotGetData(results), expected);
    [querySlash fulfill];
  }];
  [self awaitExpectations];
}

- (FIRDocumentSnapshot *)snapshotWithTimestamps:(FIRTimestamp *)timestamp {
  FIRDocumentReference *doc = [self documentRef];
  NSDictionary<NSString *, id> *data =
      @{@"timestamp" : timestamp, @"nested" : @{@"timestamp2" : timestamp}};
  [self writeDocumentRef:doc data:data];
  return [self readDocumentForRef:doc];
}

- (void)testTimestampsInSnapshots {
  FIRTimestamp *originalTimestamp = [FIRTimestamp timestampWithSeconds:100 nanoseconds:123456789];
  FIRDocumentReference *doc = [self documentRef];
  [self writeDocumentRef:doc data:testDataWithTimestamps(originalTimestamp)];

  FIRDocumentSnapshot *snapshot = [self readDocumentForRef:doc];
  NSDictionary<NSString *, id> *data = [snapshot data];
  // Timestamp are currently truncated to microseconds after being written to the database.
  FIRTimestamp *truncatedTimestamp =
      [FIRTimestamp timestampWithSeconds:originalTimestamp.seconds
                             nanoseconds:originalTimestamp.nanoseconds / 1000 * 1000];

  FIRTimestamp *timestampFromSnapshot = snapshot[@"timestamp"];
  FIRTimestamp *timestampFromData = data[@"timestamp"];
  XCTAssertEqualObjects(truncatedTimestamp, timestampFromData);
  XCTAssertEqualObjects(timestampFromSnapshot, timestampFromData);

  timestampFromSnapshot = snapshot[@"nested.timestamp2"];
  timestampFromData = data[@"nested"][@"timestamp2"];
  XCTAssertEqualObjects(truncatedTimestamp, timestampFromData);
  XCTAssertEqualObjects(timestampFromSnapshot, timestampFromData);
}
@end

@interface FIRTimestampsInSnapshotsLegacyBehaviorTests : FSTIntegrationTestCase
@end

@implementation FIRTimestampsInSnapshotsLegacyBehaviorTests

- (void)setUp {
  [super setUp];
  // Settings can only be redefined before client is initialized, so this has to happen in setUp.
  FIRFirestoreSettings *settings = self.db.settings;
  SUPPRESS_DEPRECATED_DECLARATIONS_BEGIN()
  settings.timestampsInSnapshotsEnabled = NO;
  SUPPRESS_END()
  self.db.settings = settings;
}

- (void)testLegacyBehaviorForTimestampFields {
  NSDate *originalDate = [NSDate date];
  FIRDocumentReference *doc = [self documentRef];
  [self writeDocumentRef:doc
                    data:testDataWithTimestamps([FIRTimestamp timestampWithDate:originalDate])];
  FIRDocumentSnapshot *snapshot = [self readDocumentForRef:doc];
  NSDictionary<NSString *, id> *data = [snapshot data];
  double microsecond = 0.000001;

  NSDate *timestampFromSnapshot = snapshot[@"timestamp"];
  NSDate *timestampFromData = data[@"timestamp"];
  XCTAssertEqualObjects(timestampFromSnapshot, timestampFromData);
  XCTAssertEqualWithAccuracy([timestampFromSnapshot timeIntervalSince1970],
                             [originalDate timeIntervalSince1970], microsecond);

  timestampFromSnapshot = snapshot[@"nested.timestamp2"];
  timestampFromData = data[@"nested"][@"timestamp2"];
  XCTAssertEqualObjects(timestampFromSnapshot, timestampFromData);
  XCTAssertEqualWithAccuracy([timestampFromSnapshot timeIntervalSince1970],
                             [originalDate timeIntervalSince1970], microsecond);
}

- (void)testLegacyBehaviorForServerTimestampFields {
  FIRDocumentReference *doc = [self documentRef];
  [self writeDocumentRef:doc data:@{@"when" : [FIRFieldValue fieldValueForServerTimestamp]}];

  FIRDocumentSnapshot *snapshot = [self readDocumentForRef:doc];
  XCTAssertTrue([snapshot[@"when"] isKindOfClass:[NSDate class]]);
  XCTAssertTrue([snapshot.data[@"when"] isKindOfClass:[NSDate class]]);
}

@end