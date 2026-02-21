<x-app-layout>
    <x-slot name="header">
        <div class="flex items-center justify-between gap-4">
            <h2 class="font-semibold text-xl text-gray-800 dark:text-gray-100 leading-tight">Reports</h2>
            <a href="{{ route('admin.dashboard') }}" class="inline-flex items-center px-4 py-2 text-sm font-medium text-gray-700 dark:text-gray-100 bg-white dark:bg-gray-800 border border-gray-300 dark:border-gray-600 rounded-lg hover:bg-gray-50 dark:hover:bg-gray-700">
                Back to Admin Dashboard
            </a>
        </div>
    </x-slot>

    <div class="py-10">
        <div class="max-w-7xl mx-auto sm:px-6 lg:px-8">
            <div class="bg-white dark:bg-gray-800 border border-gray-200 dark:border-gray-700 rounded-lg p-6 space-y-3 text-sm text-gray-800 dark:text-gray-100">
                @forelse ($reports as $report)
                    <div class="border border-gray-300 dark:border-gray-600 rounded-md p-3">
                        <p><strong>Reporter:</strong> {{ $report->reporter?->email ?? 'N/A' }}</p>
                        <p><strong>Reported User:</strong> {{ $report->reportedUser?->email ?? 'N/A' }}</p>
                        <p><strong>Event:</strong> {{ $report->event?->title ?? 'N/A' }}</p>
                        <p><strong>Reason:</strong> {{ $report->reason }}</p>
                        <p><strong>Details:</strong> {{ $report->details ?? '-' }}</p>
                        <p><strong>Status:</strong> {{ $report->status }}</p>
                    </div>
                @empty
                    <p class="text-gray-500 dark:text-gray-300">No reports available.</p>
                @endforelse

                {{ $reports->links() }}
            </div>
        </div>
    </div>
</x-app-layout>
