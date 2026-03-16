type LoaderProps = {
  className?: string;
};

export default function Loader({ className = "" }: LoaderProps) {
  return (
    <span
      aria-hidden="true"
      className={`inline-block h-3.5 w-3.5 animate-spin rounded-full border-2 border-current border-r-transparent ${className}`}
    />
  );
}
