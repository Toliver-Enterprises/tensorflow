// RUN: xla-opt -split-input-file -xla-legalize-tf-control-flow %s | FileCheck %s

// CHECK-LABEL: @ifRegion
// CHECK-SAME:  ([[ARG0:%.+]]: tensor<f32>, [[ARG1:%.+]]: tensor<f32>)
func.func @ifRegion(%arg0: tensor<f32>, %arg1: tensor<f32>) -> (tensor<f32>) {
  // CHECK: [[VAL0:%.+]] = mhlo.compare GT, [[ARG0]], [[ARG1]]
  %0 = "mhlo.compare"(%arg0, %arg1) {comparison_direction = #mhlo<comparison_direction GT>} : (tensor<f32>, tensor<f32>) -> tensor<i1>
  // CHECK: [[VAL1:%.+]] = "mhlo.if"([[VAL0]]) ({
  %1 = "tf.IfRegion"(%0) ({
    // CHECK: [[VAL2:%.+]] = mhlo.log [[ARG0]]
    %2 = mhlo.log %arg0 : (tensor<f32>) -> tensor<f32>
    // CHECK: mhlo.return [[VAL2]]
    "tf.Yield"(%2) : (tensor<f32>) -> ()
  }, {
    // CHECK: [[VAL3:%.+]] = mhlo.exponential [[ARG1]]
    %2 = mhlo.exponential %arg1 : (tensor<f32>) -> tensor<f32>
    // CHECK: mhlo.return [[VAL3]]
    "tf.Yield"(%2) : (tensor<f32>) -> ()
  // CHECK: }) : (tensor<i1>) -> tensor<f32>
  }) {is_stateless = true} : (tensor<i1>) -> tensor<f32>
  // CHECK: return [[VAL1]]
  func.return %1 : tensor<f32>
}

// CHECK-LABEL: func @caseRegion
// CHECK-SAME:  ([[BRANCH_INDEX:%.+]]: tensor<i32>, [[ARG0:.+]]: tensor<f32>, [[ARG1:%.+]]: tensor<f32>)
func.func @caseRegion(%index: tensor<i32>, %arg0: tensor<f32>, %arg1: tensor<f32>) -> (tensor<f32>, tensor<f32>) {
  // CHECK: [[VAL1:%.+]]:2 = "mhlo.case"([[BRANCH_INDEX]]) ({
  %0:2 = "tf.CaseRegion"(%index) ({
    // CHECK: [[VAL2:%.+]] = mhlo.exponential [[ARG1]]
    %1 = mhlo.exponential %arg1 : (tensor<f32>) -> tensor<f32>
    // CHECK: mhlo.return [[VAL2]], [[ARG1]]
    "tf.Yield"(%1, %arg1) : (tensor<f32>, tensor<f32>) -> ()
  }, {
    // CHECK: [[VAL3:%.+]] = mhlo.log [[ARG0]]
    %1 = mhlo.log %arg0 : (tensor<f32>) -> tensor<f32>
    // CHECK: mhlo.return [[VAL3]], [[ARG1]]
    "tf.Yield"(%1, %arg1) : (tensor<f32>, tensor<f32>) -> ()
  }, {
    // CHECK: [[VAL4:%.+]] = mhlo.floor [[ARG0]]
    %1 = "mhlo.floor"(%arg0) : (tensor<f32>) -> tensor<f32>
    // CHECK: mhlo.return [[VAL4]], [[ARG1]]
    "tf.Yield"(%1, %arg1) : (tensor<f32>, tensor<f32>) -> ()
  // CHECK: }) : (tensor<i32>) -> (tensor<f32>, tensor<f32>)
  }) {is_stateless = true} : (tensor<i32>) -> (tensor<f32>, tensor<f32>)
  // CHECK: return [[VAL1]]#0, [[VAL1]]#1 : tensor<f32>, tensor<f32>
  func.return %0#0, %0#1 : tensor<f32>, tensor<f32>
}

// -----

// This test case also ensures the mhlo dialect is loaded as a dependency by the
// pass and hence the split here.

// CHECK-LABEL: func @whileRegion
func.func @whileRegion() -> tensor<i32> {
  %0 = "tf.Const"()  {value = dense<0> : tensor<i32>}  : () -> tensor<i32>
  %1 = "tf.Const"()  {value = dense<-1> : tensor<i32>}  : () -> tensor<i32>
  %2:3 = "tf.WhileRegion"(%0, %1, %0) ({
  ^cond(%carg0: tensor<i32>, %carg1: tensor<i32>, %carg2: tensor<i32>):
    %3 = "tf.Const"()  {value = dense<1> : tensor<i1>}  : () -> tensor<i1>
    "tf.Yield"(%3) : (tensor<i1>) -> ()
  }, {
  ^body(%barg0: tensor<i32>, %barg1: tensor<i32>, %barg2: tensor<i32>):
    %4 = "tf.Const"()  {value = dense<1> : tensor<i32>}  : () -> tensor<i32>
    "tf.Yield"(%4, %4, %4) : (tensor<i32>, tensor<i32>, tensor<i32>) -> ()
  }) {is_stateless = true, parallel_iterations = 10 : i64} : (tensor<i32>, tensor<i32>, tensor<i32>) -> (tensor<i32>, tensor<i32>, tensor<i32>)
  func.return %2#2 : tensor<i32>
}

// -----

// CHECK-LABEL: func @whileRegion
func.func @whileRegion() -> tensor<i32> {
  // CHECK: [[VAL0:%.+]] = "tf.Const"
  %0 = "tf.Const"()  {value = dense<0> : tensor<i32>}  : () -> tensor<i32>
  // CHECK: [[VAL1:%.+]] = "tf.Const"
  %1 = "tf.Const"()  {value = dense<-1> : tensor<i32>}  : () -> tensor<i32>
  // CHECK: [[VAL2:%.+]]:3 = mhlo.while([[ITER_ARG0:.*]] = [[VAL0]], [[ITER_ARG1:.*]] =  [[VAL1]], [[ITER_ARG2:.*]] =  [[VAL0]])
  %2:3 = "tf.WhileRegion"(%0, %1, %0) ({
  ^cond(%carg0: tensor<i32>, %carg1: tensor<i32>, %carg2: tensor<i32>):
    // CHECK: [[VAL3:%.+]] = "tf.Const"
    %3 = "tf.Const"()  {value = dense<10> : tensor<i32>}  : () -> tensor<i32>
    // CHECK: [[VAL4:%.+]] = mhlo.compare LT, [[ITER_ARG2]], [[VAL3]]
    %4 = "mhlo.compare"(%carg2, %3) {comparison_direction = #mhlo<comparison_direction LT>} : (tensor<i32>, tensor<i32>) -> tensor<i1>
    // CHECK: mhlo.return [[VAL4]]
    "tf.Yield"(%4) : (tensor<i1>) -> ()
  }, {
  ^body(%barg0: tensor<i32>, %barg1: tensor<i32>, %barg2: tensor<i32>):
    // CHECK: [[VAL5:%.+]] = "tf.Const"
    %5 = "tf.Const"()  {value = dense<1> : tensor<i32>}  : () -> tensor<i32>
    // CHECK: [[VAL6:%.+]] = mhlo.add [[ITER_ARG2]], [[VAL5]]
    %6 = mhlo.add %barg2, %5 : tensor<i32>
    // CHECK: [[VAL7:%.+]] = mhlo.add [[ITER_ARG0]], [[VAL5]]
    %7 = mhlo.add %barg0, %5 : tensor<i32>
    // CHECK: mhlo.return [[VAL7]], [[ITER_ARG1]], [[VAL6]]
    "tf.Yield"(%7, %barg1, %6) : (tensor<i32>, tensor<i32>, tensor<i32>) -> ()
  }) {is_stateless = true, parallel_iterations = 10 : i64} : (tensor<i32>, tensor<i32>, tensor<i32>) -> (tensor<i32>, tensor<i32>, tensor<i32>)
  // CHECK: return [[VAL2]]#2
  func.return %2#2 : tensor<i32>
}

// -----

// CHECK-LABEL: func @whileRegionImplicitInputs
// CHECK-SAME:  ([[ARG0:%.+]]: tensor<i32>)
func.func @whileRegionImplicitInputs(%arg0: tensor<i32>) -> tensor<i32> {
  // CHECK: [[VAL0:%.+]] = mhlo.constant dense<0>
  %0 = mhlo.constant dense<0> : tensor<i32>
  // CHECK: [[VAL1:%.+]] = mhlo.constant dense<-1>
  %1 = mhlo.constant dense<-1> : tensor<i32>
  // CHECK: [[VAL2:%.+]] = mhlo.while([[ITER_ARG0:.*]] = [[ARG0]])
  %2 = "tf.WhileRegion"(%arg0) ({
  ^cond(%carg0: tensor<i32>):
    // CHECK: [[VAL3:%.+]] = mhlo.compare LT, [[ITER_ARG0]], [[VAL0]]
    %3 = mhlo.compare LT, %carg0, %0 : (tensor<i32>, tensor<i32>) -> tensor<i1>
    // CHECK: mhlo.return [[VAL3]]
    "tf.Yield"(%3) : (tensor<i1>) -> ()
  }, {
  ^body(%barg0: tensor<i32>):
    // CHECK: [[VAL3:%.+]] = mhlo.add [[ITER_ARG0]], [[VAL1]]
    %3 = mhlo.add %barg0, %1 : tensor<i32>
    // CHECK: [[VAL4:%.+]] = mhlo.add [[ITER_ARG0]], [[VAL3]]
    %4 = mhlo.add %barg0, %3 : tensor<i32>
    // CHECK: mhlo.return [[VAL4]]
    "tf.Yield"(%4) : (tensor<i32>) -> ()
  }) {is_stateless = true, parallel_iterations = 10 : i64} : (tensor<i32>) -> tensor<i32>
  // CHECK: return [[VAL2]]
  func.return %2 : tensor<i32>
}


// CHECK-LABEL: func @whileRegionMultipleImplicitInputs
func.func @whileRegionMultipleImplicitInputs() {
  // CHECK: [[VAL0:%.+]] = mhlo.constant dense<0>
  %0 = mhlo.constant dense<0> : tensor<i32>
  // CHECK: [[VAL1:%.+]] = mhlo.constant dense<-1>
  %1 = mhlo.constant dense<-1> : tensor<i32>
  // CHECK: mhlo.while()
  "tf.WhileRegion"() ({
    // CHECK: [[VAL3:%.+]] = mhlo.compare LT, [[VAL0]], [[VAL1]]
    %2 = "mhlo.compare"(%0, %1) {comparison_direction = #mhlo<comparison_direction LT>} : (tensor<i32>, tensor<i32>) -> tensor<i1>
    // CHECK: mhlo.return [[VAL3]]
    "tf.Yield"(%2) : (tensor<i1>) -> ()
  }, {
    // CHECK: [[VAL3:%.+]] = mhlo.add [[VAL0]], [[VAL1]]
    %2 = mhlo.add %0, %1 : tensor<i32>
    // CHECK: mhlo.return
    "tf.Yield"() : () -> ()
  }) {is_stateless = true, parallel_iterations = 10 : i64} : () -> ()
  // CHECK: return
  func.return
}
