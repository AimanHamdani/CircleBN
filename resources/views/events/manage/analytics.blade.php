<x-app-layout>
    <x-slot name="header">
        <div class="flex items-center justify-between">
            <h2 class="font-semibold text-xl text-gray-800 dark:text-gray-100 leading-tight">
                Analytics &mdash; {{ $event->title }}
            </h2>
            <a href="{{ route('events.manage.show', $event) }}" class="text-sm text-gray-500 dark:text-gray-400 hover:text-gray-700 dark:hover:text-gray-200 transition">&larr; Back to Dashboard</a>
        </div>
    </x-slot>

    <div class="py-8">
        <div class="max-w-7xl mx-auto sm:px-6 lg:px-8 space-y-6">
            {{-- Key Metrics --}}
            <div class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4">
                <div class="bg-white dark:bg-gray-800 shadow-sm rounded-lg p-6">
                    <p class="text-xs text-gray-500 dark:text-gray-400 uppercase tracking-wider">Total Registered</p>
                    <p class="text-3xl font-bold text-gray-900 dark:text-gray-100 mt-2">{{ $totalRegistered }}</p>
                    @if($event->capacity)
                        <div class="mt-2 w-full bg-gray-200 dark:bg-gray-700 rounded-full h-2">
                            <div class="bg-indigo-600 rounded-full h-2" style="width: {{ min(100, ($totalRegistered / $event->capacity) * 100) }}%"></div>
                        </div>
                        <p class="text-xs text-gray-500 dark:text-gray-400 mt-1">{{ $event->capacity - $totalRegistered }} spots remaining</p>
                    @endif
                </div>

                <div class="bg-white dark:bg-gray-800 shadow-sm rounded-lg p-6">
                    <p class="text-xs text-gray-500 dark:text-gray-400 uppercase tracking-wider">Checked In</p>
                    <p class="text-3xl font-bold text-green-600 dark:text-green-400 mt-2">{{ $checkedIn }}</p>
                    @if($totalRegistered > 0)
                        <p class="text-xs text-gray-500 dark:text-gray-400 mt-1">{{ number_format(($checkedIn / $totalRegistered) * 100, 1) }}% attendance rate</p>
                    @endif
                </div>

                <div class="bg-white dark:bg-gray-800 shadow-sm rounded-lg p-6">
                    <p class="text-xs text-gray-500 dark:text-gray-400 uppercase tracking-wider">Dropped Off</p>
                    <p class="text-3xl font-bold text-red-600 dark:text-red-400 mt-2">{{ $droppedOff }}</p>
                    @if($totalRegistered > 0)
                        <p class="text-xs text-gray-500 dark:text-gray-400 mt-1">{{ number_format(($droppedOff / $totalRegistered) * 100, 1) }}% drop-off rate</p>
                    @endif
                </div>

                <div class="bg-white dark:bg-gray-800 shadow-sm rounded-lg p-6">
                    <p class="text-xs text-gray-500 dark:text-gray-400 uppercase tracking-wider">Revenue</p>
                    <p class="text-3xl font-bold text-gray-900 dark:text-gray-100 mt-2">BND {{ number_format($revenue, 2) }}</p>
                    @if($totalRegistered > 0)
                        <p class="text-xs text-gray-500 dark:text-gray-400 mt-1">BND {{ number_format($revenue / $totalRegistered, 2) }} avg / participant</p>
                    @endif
                </div>
            </div>

            {{-- Gender & Age Distribution --}}
            <div class="grid grid-cols-1 lg:grid-cols-2 gap-6">
                {{-- Gender Distribution --}}
                <div class="bg-white dark:bg-gray-800 shadow-sm rounded-lg p-6">
                    <h3 class="text-lg font-medium text-gray-900 dark:text-gray-100 mb-4">Gender Distribution</h3>
                    @if($totalRegistered > 0)
                        <div class="space-y-3">
                            @php
                                $genderColors = [
                                    'male' => 'bg-blue-500',
                                    'female' => 'bg-pink-500',
                                    'other' => 'bg-purple-500',
                                ];
                            @endphp
                            @foreach($genderDistribution as $gender => $count)
                                <div>
                                    <div class="flex justify-between text-sm mb-1">
                                        <span class="text-gray-700 dark:text-gray-300 capitalize">{{ $gender ?? 'Unknown' }}</span>
                                        <span class="text-gray-500 dark:text-gray-400">{{ $count }} ({{ number_format(($count / $totalRegistered) * 100, 1) }}%)</span>
                                    </div>
                                    <div class="w-full bg-gray-200 dark:bg-gray-700 rounded-full h-3">
                                        <div class="{{ $genderColors[$gender] ?? 'bg-gray-500' }} rounded-full h-3 transition-all duration-500" style="width: {{ ($count / $totalRegistered) * 100 }}%"></div>
                                    </div>
                                </div>
                            @endforeach
                        </div>
                    @else
                        <p class="text-sm text-gray-500 dark:text-gray-400">No data available yet.</p>
                    @endif
                </div>

                {{-- Age Distribution --}}
                <div class="bg-white dark:bg-gray-800 shadow-sm rounded-lg p-6">
                    <h3 class="text-lg font-medium text-gray-900 dark:text-gray-100 mb-4">Age Distribution</h3>
                    @if($totalRegistered > 0)
                        <div class="space-y-3">
                            @php
                                $ageColors = ['bg-indigo-500', 'bg-blue-500', 'bg-cyan-500', 'bg-teal-500', 'bg-green-500', 'bg-amber-500'];
                                $colorIndex = 0;
                            @endphp
                            @foreach($ageRanges as $range => $count)
                                <div>
                                    <div class="flex justify-between text-sm mb-1">
                                        <span class="text-gray-700 dark:text-gray-300">{{ $range }}</span>
                                        <span class="text-gray-500 dark:text-gray-400">{{ $count }}</span>
                                    </div>
                                    <div class="w-full bg-gray-200 dark:bg-gray-700 rounded-full h-3">
                                        <div class="{{ $ageColors[$colorIndex % count($ageColors)] }} rounded-full h-3 transition-all duration-500" style="width: {{ $totalRegistered > 0 ? ($count / $totalRegistered) * 100 : 0 }}%"></div>
                                    </div>
                                </div>
                                @php $colorIndex++ @endphp
                            @endforeach
                        </div>
                    @else
                        <p class="text-sm text-gray-500 dark:text-gray-400">No data available yet.</p>
                    @endif
                </div>
            </div>
        </div>
    </div>
</x-app-layout>
