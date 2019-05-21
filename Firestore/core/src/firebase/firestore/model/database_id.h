/*
 * Copyright 2018 Google
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

#ifndef FIRESTORE_CORE_SRC_FIREBASE_FIRESTORE_MODEL_DATABASE_ID_H_
#define FIRESTORE_CORE_SRC_FIREBASE_FIRESTORE_MODEL_DATABASE_ID_H_

#include <memory>
#include <string>

#include "Firestore/core/src/firebase/firestore/util/comparison.h"

namespace firebase {
namespace firestore {
namespace model {

/** A DatabaseId represents a particular database in the Firestore. */
class DatabaseId : public util::Comparable<DatabaseId> {
 public:
  /** The default name for "unset" database ID in resource names. */
  static constexpr const char* kDefault = "(default)";

#if defined(__OBJC__)
  // For objective-c++ initialization; to be removed after migration.
  // Do NOT use in C++ code.
  DatabaseId() = default;
#endif  // defined(__OBJC__)

  /**
   * Creates and returns a new DatabaseId.
   *
   * @param project_id The project for the database.
   * @param database_id The database in the project to use.
   */
  DatabaseId(std::string project_id, std::string database_id);

  const std::string& project_id() const {
    return rep_->project_id;
  }

  const std::string& database_id() const {
    return rep_->database_id;
  }

  /** Whether this is the default database of the project. */
  bool IsDefaultDatabase() const {
    return rep_->database_id == kDefault;
  }

  util::ComparisonResult CompareTo(const DatabaseId& rhs) const;

  size_t Hash() const;

 private:
  // DocumentIds are copied into every ReferenceValue we create so hide the
  // actual values behind a shared_ptr to make copying cheaper.
  struct Rep {
    std::string project_id;
    std::string database_id;
  };

  std::shared_ptr<Rep> rep_;
};

}  // namespace model
}  // namespace firestore
}  // namespace firebase

#endif  // FIRESTORE_CORE_SRC_FIREBASE_FIRESTORE_MODEL_DATABASE_ID_H_