<x-app-layout>
    <x-slot name="header">
        <div class="flex items-center justify-between gap-4">
            <h2 class="font-semibold text-xl text-gray-800 leading-tight">Flagged Content</h2>
            <a href="{{ route('admin.dashboard') }}" class="inline-flex items-center px-4 py-2 text-sm font-medium text-gray-700 bg-white border border-gray-300 rounded-lg hover:bg-gray-50">
                Back to Admin Dashboard
            </a>
        </div>
    </x-slot>

    <div class="py-10">
        <div class="max-w-7xl mx-auto sm:px-6 lg:px-8">
            <div class="bg-white border border-gray-200 rounded-lg p-6 space-y-3 text-sm">
                @forelse ($reports as $report)
                    <div class="border rounded-md p-3">
                        <p><strong>Reporter:</strong> {{ $report->reporter?->email ?? 'N/A' }}</p>
                        <p><strong>Reported User:</strong> {{ $report->reportedUser?->email ?? 'N/A' }}</p>
                        <p><strong>Event:</strong> {{ $report->event?->title ?? 'N/A' }}</p>
                        <p><strong>Reason:</strong> {{ $report->reason }}</p>
                        <p><strong>Details:</strong> {{ $report->details ?? '-' }}</p>
                    </div>
                @empty
                    <p>No flagged content in open state.</p>
                @endforelse

                {{ $reports->links() }}
            </div>
        </div>
    </div>
</x-app-layout>
