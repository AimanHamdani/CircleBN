<x-app-layout>
    <x-slot name="header">
        <div class="flex items-center justify-between gap-4">
            <h2 class="font-semibold text-xl text-gray-800 dark:text-gray-100 leading-tight">Analytics</h2>
            <a href="{{ route('admin.dashboard') }}" class="inline-flex items-center px-4 py-2 text-sm font-medium text-gray-700 dark:text-gray-100 bg-white dark:bg-gray-800 border border-gray-300 dark:border-gray-600 rounded-lg hover:bg-gray-50 dark:hover:bg-gray-700">
                Back to Admin Dashboard
            </a>
        </div>
    </x-slot>

    <div class="py-10">
        <div class="max-w-7xl mx-auto sm:px-6 lg:px-8 space-y-6">
            <div class="grid grid-cols-1 md:grid-cols-2 xl:grid-cols-3 gap-6">
                <div class="bg-white dark:bg-gray-800 border border-gray-200 dark:border-gray-700 rounded-lg p-5">
                    <p class="text-sm text-gray-500 dark:text-gray-300">Total Registrations</p>
                    <p class="text-2xl font-semibold mt-2 text-gray-900 dark:text-gray-100">{{ $totalRegistrations }}</p>
                </div>
                <div class="bg-white dark:bg-gray-800 border border-gray-200 dark:border-gray-700 rounded-lg p-5">
                    <p class="text-sm text-gray-500 dark:text-gray-300">Revenue</p>
                    <p class="text-2xl font-semibold mt-2 text-gray-900 dark:text-gray-100">BND {{ number_format($totalRevenue, 2) }}</p>
                </div>
                <div class="bg-white dark:bg-gray-800 border border-gray-200 dark:border-gray-700 rounded-lg p-5">
                    <p class="text-sm text-gray-500 dark:text-gray-300">Age Range</p>
                    <p class="text-2xl font-semibold mt-2 text-gray-900 dark:text-gray-100">{{ $ageRange }}</p>
                </div>
                <div class="bg-white dark:bg-gray-800 border border-gray-200 dark:border-gray-700 rounded-lg p-5">
                    <p class="text-sm text-gray-500 dark:text-gray-300">Drop-off Rate</p>
                    <p class="text-2xl font-semibold mt-2 text-gray-900 dark:text-gray-100">{{ $dropOffRate }}%</p>
                </div>
                <div class="bg-white dark:bg-gray-800 border border-gray-200 dark:border-gray-700 rounded-lg p-5">
                    <p class="text-sm text-gray-500 dark:text-gray-300">Check-in Rate</p>
                    <p class="text-2xl font-semibold mt-2 text-gray-900 dark:text-gray-100">{{ $checkInRate }}%</p>
                </div>
                <div class="bg-white dark:bg-gray-800 border border-gray-200 dark:border-gray-700 rounded-lg p-5">
                    <p class="text-sm text-gray-500 dark:text-gray-300">Gender Distribution</p>
                    <div class="mt-2 text-sm text-gray-700 dark:text-gray-200 space-y-1">
                        @forelse ($genderDistribution as $gender => $total)
                            <p>{{ $gender }}: {{ $total }}</p>
                        @empty
                            <p>No gender data yet.</p>
                        @endforelse
                    </div>
                </div>
            </div>
        </div>
    </div>
</x-app-layout>
