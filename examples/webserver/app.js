angular.module('example', ['n3-line-chart'])
.controller('ExampleCtrl', function($scope, $http) {

	$scope.data = [
//{x: 0, value: 4, otherValue: 14},
//{x: 1, value: 8, otherValue: 1},
//{x: 2, value: 15, otherValue: 11},
//{x: 3, value: 16, otherValue: 147},
//{x: 4, value: 23, otherValue: 87},
//{x: 5, value: 42, otherValue: 45}
];

            
$scope.addData = function() {
	$http.get('/csv/test', {cache: false})
	.success(
		function(data, status, header, config){
			if (data) {
				console.log(data);
				data.x=$scope.data.length;
				$scope.data.push(data);
                if ($scope.data.length > 61) {
                    $scope.data.splice(0, 1);
                }
				$scope.options.axes.x.min = $scope.minimum;
                $scope.options.axes.x.max = $scope.maximum;
				$scope.latestLatency = data.y;
				$scope.lengthOfCableInM = ($scope.speedOfLightInMPerSInCopper / 1000 / 1000 / 1000) * ($scope.latestLatency-$scope.averageModulationTimeInNs);// * $scope.latestLatency * 1000) / 1000;
				$scope.lengthOfCableInFeet = $scope.lengthOfCableInM * $scope.mToFeetFactor;
			}
		}
		);
//$scope.latestLatency++;
//$scope.data.push({ x:$scope.latestLatency, y: 20});
//if ($scope.data.length > 11) {
//            $scope.data.splice(0, 1);
//}
//$scope.options.axes.x.min = $scope.data[0].x;
//$scope.options.axes.x.max = $scope.data[$scope.data.length-1].x;
//$scope.latestLatency = $scope.latestLatency + 1;
//$scope.options.axes.x.max = $scope.data.length;
};
setInterval($scope.addData, 1000);

$scope.options = {
	axes: {
	x: {key: 'x', labelFunction: function(y) {return y;}, type: 'linear', min: 0},//max: $scope.data.length, ticks: 2},
	y: {type: 'linear', min: 0},
},
	series: [
	{y: 'y', color: 'steelblue', thickness: '2px', type: 'area', striped: false, label: 'Average Latency'}
	//,{y: 'otherValue', axis: 'y2', color: 'lightsteelblue', visible: false, drawDots: true, dotSize: 2}
],
	lineMode: 'linear',
	tension: 0.7,
	tooltip: {mode: 'scrubber', formatter: function(x, y, series) {return 'latency';}},
	drawLegend: true,
	drawDots: true,
	columnsHGap: 5
	};

            $scope.minimum = 0;
            $scope.maximum = 60;
$scope.latestLatency = 0;

$scope.averageModulationTimeInNs = 2195.20;
$scope.speedOfLightInMPerS = 299792458;
$scope.speedOfLightInMPerSInCopper = $scope.speedOfLightInMPerS * 0.59;
$scope.lengthOfCableInM = 0;
$scope.lengthOfCableInFeet = 0;
$scope.mToFeetFactor = 3.2808399;
});